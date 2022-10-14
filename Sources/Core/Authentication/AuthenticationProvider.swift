//
//  AuthenticationProvider.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Alamofire
import Combine
import CommonCrypto

class AuthenticationProvider {
    private weak var client: Client!
    private(set) var isAuthenticating = false
    
    required init(client: Client) {
        self.client = client
    }

    /// This function is to authorize the request
    ///
    /// - Parameters:
    ///   - request: `Request`
    ///
    /// - Returns: `Promise<Request>`
    func authorize(request: Request) -> AnyPublisher<Request, Error> {
        // Define headers
        if let headers = request.headers {
            request.useHeaders = headers
        }

        // How should the request be authorized?
        switch request.authentication {
        case .client:
            // Regular client_id / client_secret
            guard let clientID = client.config.authentication.clientID, let clientSecret = client.config.authentication.clientSecret else {
                return Error.missingClientAuthentication.asPublisher(outputType: Request.self)
            }

            switch client.config.authentication.authorization {
            case .none:
                break
            case .basicHeader:
                // Just add an `Authorization` header
                guard let base64 = "\(clientID):\(clientSecret)".data(using: .utf8)?.base64EncodedString() else {
                    return Error.missingClientAuthentication.asPublisher(outputType: Request.self)
                }
                request.useHeaders["Authorization"] = "Basic \(base64)"

            case .requestBody:
                // Alternatively, the authorization server MAY support including the
                // client credentials in the request-body using the following

                var parameters = request.parameters ?? [:]
                if parameters["client_id"] == nil {
                    parameters["client_id"] = clientID
                }

                if parameters["client_secret"] == nil {
                    parameters["client_secret"] = clientSecret
                }

                if !parameters.keys.isEmpty {
                    request.parameters = parameters
                }
                
                if client.config.logging.maskTokens {
                    var parametersLoggingOptions: [String: KeyLoggingOption] = request.loggingOption?.request ?? [:]
                    
                    if parametersLoggingOptions["client_secret"] == nil {
                        parametersLoggingOptions["client_secret"] = .halfMasked
                        
                        if request.loggingOption == nil {
                            request.loggingOption = LoggingOption()
                        }
                        request.loggingOption?.request = parametersLoggingOptions
                    }
                }
            }

        // If the client requires an OAuth2 authorization;
        // continue to `_authorizeOAuth(request:, grantType:)`
        case .oauth2(let grantType):
            return _authorizeOAuth(request: request, grantType: grantType)

        case .none:
            break
        }

        return Just(request).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    /// Here we're going to do either of the following:
    ///
    /// 1. If the user has a valid access-token and it's not expired, use it.
    /// 2. If the user has an expired `password` access-token, refresh it
    /// 3. If you need a `client_credentials` grantType and the access-token is expired. Create a new one
    private func _authorizeOAuth(request: Request,
                                 grantType: OAuthenticationGrantType) -> AnyPublisher<Request, Error> {
        var parameters: Parameters = [:]
        var grantType = grantType

        let host = (self.client.config.authentication.host ?? (request.host ?? self.client.config.host)) ?? ""
        if let accessTokenObj = AccessToken.get(host: host, grantType: grantType),
            let accessToken = accessTokenObj.accessToken {
            let expiresIn = Int((accessTokenObj.expireDate ?? Date()).timeIntervalSinceNow)
            
            if !accessTokenObj.isExpired {
                if request.loggingOption?.request?.isIgnoreAll != true {
                    client.logger?.notice("[?] Access token expires in: \(expiresIn)s")
                }
                request.useHeaders["Authorization"] = "Bearer " + accessToken
                return Just(request).setFailureType(to: Error.self).eraseToAnyPublisher()
            }

            if request.loggingOption?.request?.isIgnoreAll != true {
                client.logger?.warning("Access-token expired \(-expiresIn)s ago, refreshing ...")
            }
            if grantType.refreshUsingRefreshToken, let refreshToken = accessTokenObj.refreshToken {
                grantType = .refreshToken
                parameters["refresh_token"] = refreshToken
            }
        }

        if grantType.refreshUsingRefreshToken {
            return Error.missingClientAuthentication.asPublisher(outputType: Request.self)
        }

        return sendOAuthRequest(initialRequest: request, grantType: grantType, parameters: parameters)
            .flatMap { [weak self] _ -> AnyPublisher<Request, Error> in
                guard let self = self else {
                    return AnyPublisher<Request, Error>.never()
                }
                return self._authorizeOAuth(request: request, grantType: grantType)
            }.eraseToAnyPublisher()
    }

    func sendOAuthRequest(initialRequest: Request? = nil, grantType: OAuthenticationGrantType, parameters: Parameters? = nil) -> AnyPublisher<Void, Error> {
        if isAuthenticating && initialRequest?.requiresOAuthentication == true {
            client.logger?.trace("Already authenticating, stopping the concurrent request")
            return Error.concurrentAuthentication.asPublisher(outputType: Void.self)
        }

        isAuthenticating = true
        
        var parameters = parameters ?? [:]
        parameters["grant_type"] = grantType.rawValue
        
        let request = Request {
            $0.path = client.config.authentication.path
            if grantType == .refreshToken, let path = client.config.authentication.refreshTokenPath {
                $0.path = path
            }
            $0.httpMethod = .post
            $0.host = client.config.authentication.host
            $0.encoding = client.config.authentication.encoding ?? URLEncoding.default
            $0.authentication = .client
            $0.parameters = parameters
            $0.loggingOption = LoggingOption(request: [
                "password": .masked,
                "username": .halfMasked,
                "refresh_token": client.config.logging.maskTokens ? .halfMasked : .default,
                "client_secret": client.config.logging.maskTokens ? .halfMasked : .default
            ], response: [
                "access_token": client.config.logging.maskTokens ? .halfMasked : .default,
                "refresh_token": client.config.logging.maskTokens ? .halfMasked : .default,
            ])
        }

        return client.request(request).tryMap { [weak self, client] response -> Void in
            let accessToken = try response.map(to: AccessToken.self)
            accessToken.host = (request.host ?? client?.config.host) ?? ""
            accessToken.grantType = grantType
            accessToken.store()
            
            client?.logger?.debug("Store access-token: \(optionalDescription(accessToken))")
            client?.authorizationGrantType = accessToken.grantType
            self?.isAuthenticating = false
            return ()
        }.tryCatch { [weak self, client] error -> AnyPublisher<Void, Error> in
            defer {
                self?.isAuthenticating = false
            }
            guard error == Error.invalidGrant, grantType == .refreshToken else {
                throw error
            }
            // If the server responds with 'invalid_grant' for a refresh_token grantType
            // then the refresh-token is invalid and therefore the access-token is too.
            // So we can completely remove the access-token, since it is in no way able to revalidate.
            client?.logger?.warning("Clearing access-token; invalid refresh-token")
            client?.clearAccessToken()
            
            throw Error.refreshTokenInvalidated
        }.mapError { error in
            return Error(from: error).set(request: request)
        }.eraseToAnyPublisher()
    }
    
    /// Create an authorization code request to request an access token
    /// - Returns: `AnyPublisher<AuthorizationCodeRequest, Error>`
    func createAuthorizationCodeRequest(scope: [String], redirectUri: String) -> AnyPublisher<AuthorizationCodeRequest, Error> {
        return Deferred { [weak self] in
            Future { promise in
                guard let self = self else {
                    promise(.failure(Error.unknown()))
                    return
                }
                
                guard let host = self.client.config.authentication.host,
                      let clientId = self.client.config.authentication.clientID else {
                    promise(.failure(Error.invalidRequest("Missing 'host' and/or 'clientId'")))
                    return
                }
                
                let state = UUID().uuidString
                let scopes = scope.joined(separator: " ").urlEncoded
                let urlString = String.combined(host: host, path: self.client.config.authentication.authorizationPath)
                
                var authURLString = urlString +
                    "?client_id=\(clientId)" +
                    "&response_type=code" +
                    "&state=\(state)" +
                    "&scope=\(scopes)" +
                    "&redirect_uri=\(redirectUri.urlEncoded)"
                
                var codeVerifier: String? = nil
                if self.client.config.authentication.pkceEnabled {
                    codeVerifier = self._createCodeVerifier()
                    let codeChallenge = self._createCodeChallenge(from: codeVerifier!)
                    
                    authURLString += "&code_challenge=\(codeChallenge)&code_challenge_method=S256"
                }
                
                print("authUrl: \(authURLString)")
                
                guard let authURL = URL(string: authURLString) else {
                    promise(.failure(Error.invalidUrl))
                    return
                }
                
                let request = AuthorizationCodeRequest(
                    url: authURL,
                    redirectUri: redirectUri,
                    state: state,
                    codeVerifier: codeVerifier
                )
                
                promise(.success(request))
                
            }
        }.eraseToAnyPublisher()
    }
    
    func requestTokenFromAuthorizationCode(initialRequest request: AuthorizationCodeRequest, code: String) -> AnyPublisher<Void, Error> {
        var parameters = [
            "redirect_uri": request.redirectUri,
            "code": code,
        ]
        
        if client.config.authentication.pkceEnabled, let codeVerifier = request.codeVerifier {
            parameters["code_verifier"] = codeVerifier
        }
        
        return sendOAuthRequest(grantType: .authorizationCode, parameters: parameters)
    }
    
    private func _createCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "=", with: "-")
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func _createCodeChallenge(from verifier: String) -> String {
        let codeVerifierBytes = verifier.data(using: .ascii)!
        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        codeVerifierBytes.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(codeVerifierBytes.count), &buffer)
        }
        
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    ///
    /// Handle a manual OAuth authentication call when using differently named properties
    ///
    /// - Parameters:
    ///     - grantType: `OAuthenticationGrantType`
    ///     - accessToken: `String`
    ///     - refreshToken: `OAuthenticationGrantType`
    ///     - expiresIn: `Int`
    ///     - host: `String?`
    ///
    /// - Returns: `Void`
    ///
    func handleManualOAuthRequest(grantType: OAuthenticationGrantType,
                                  accessToken: String,
                                  refreshToken: String,
                                  expireDate: Date,
                                  host: String) {
        let accessTokenObject = AccessToken(grantType: grantType, accessToken: accessToken, refreshToken: refreshToken, expireDate: expireDate, host: host)
        accessTokenObject.store()
        
        client.logger?.debug("Store access-token: \(optionalDescription(accessToken))")
        client.authorizationGrantType = grantType
    }

    // MARK: - Recover
    // --------------------------------------------------------

    func recover(from error: Swift.Error, request: Request) -> AnyPublisher<CobaltResponse, Error> {
        // If we receive an 'invalid_grant' error and we tried to do a refresh_token authentication
        // The access-token and underlying refresh-token is invalid
        // So we can revoke the access-token
        if error == Error.invalidGrant,
            case let .oauth2(grantType) = request.authentication,
            grantType != .refreshToken {

            let accessToken = AccessToken(host: (client.config.authentication.host ?? (request.host ?? client.config.host)) ?? "")
            if let logReq = request.loggingOption?.request?["*"], case KeyLoggingOption.ignore = logReq {
            } else {
                client.logger?.warning("Access-token expired; invalidating access-token")
            }

            accessToken.invalidate()
            return client.request(request)

        } else if error == Error.concurrentAuthentication {
            // Retry the request, which will probably add it to the queue because there's an authentication request pending
            return client.request(request)
        }
        return Fail(error: Error(from: error)).eraseToAnyPublisher()
    }
}

extension AnyPublisher {
    static func never() -> AnyPublisher<Output, Failure> {
        return Empty(completeImmediately: false, outputType: Output.self, failureType: Failure.self).eraseToAnyPublisher()
    }
}
