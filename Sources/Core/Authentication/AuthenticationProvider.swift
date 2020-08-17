//
//  AuthenticationProvider.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Alamofire
import RxCocoa
import RxSwift
import SwiftyJSON

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
    func authorize(request: Request) throws -> Single<Request> {
        // Define headers
        if let headers = request.headers {
            request.useHeaders = headers
        }

        // How should the request be authorized?
        switch request.authentication {
        case .client:
            // Regular client_id / client_secret
            guard let clientID = client.config.clientID, let clientSecret = client.config.clientSecret else {
                throw Error.missingClientAuthentication
            }

            switch client.config.clientAuthorization {
            case .none:
                break
            case .basicHeader:
                // Just add an `Authorization` header
                guard let base64 = "\(clientID):\(clientSecret)".data(using: .utf8)?.base64EncodedString() else {
                    throw Error.missingClientAuthentication
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

                if client.config.maskTokens {
                    var parametersLoggingOptions: [String: KeyLoggingOption] = request.loggingOption?.request ?? [:]
                    
                    if parametersLoggingOptions["client_secret"] == nil {
                        parametersLoggingOptions["client_secret"] = .halfMasked
                    }
                    
                    if request.loggingOption?.request == nil {
                        request.loggingOption = LoggingOption(request: parametersLoggingOptions, response: request.loggingOption?.response)
                    }
                }
            }

        // If the client requires an OAuth2 authorization;
        // continue to `_authorizeOAuth(request:, grantType:)`
        case .oauth2(let grantType):
            return try _authorizeOAuth(request: request, grantType: grantType)

        default:
            break
        }

        return Single<Request>.just(request)
    }

    /// Here we're going to do either of the following:
    ///
    /// 1. If the user has a valid access-token and it's not expired, use it.
    /// 2. If the user has an expired `password` access-token, refresh it
    /// 3. If you need a `client_credentials` grantType and the access-token is expired. Create a new one
    private func _authorizeOAuth(request: Request,
                                 grantType: OAuthenticationGrantType) throws -> Single<Request> {
        var parameters: Parameters = [:]
        var grantType = grantType

        let host = (request.host ?? self.client.config.host) ?? ""
        if let accessTokenObj = AccessToken.get(host: host, grantType: grantType),
            let accessToken = accessTokenObj.accessToken {

            if !accessTokenObj.isExpired {
                if let logReq = request.loggingOption?.request?["*"], case KeyLoggingOption.ignore = logReq {
                } else {
                    let expiresIn = Int((accessTokenObj.expireDate ?? Date()).timeIntervalSinceNow)
                    client.logger?.notice("[?] Access token expires in: \(expiresIn)s")
                }
                request.useHeaders["Authorization"] = "Bearer " + accessToken
                return Single<Request>.just(request)
            }

            if let logReq = request.loggingOption?.request?["*"], case KeyLoggingOption.ignore = logReq {
            } else {
                client.logger?.warning("Access-token expired, refreshing ...")
            }
            if grantType == .password, let refreshToken = accessTokenObj.refreshToken {
                grantType = .refreshToken
                parameters["refresh_token"] = refreshToken
            }
        }

        if grantType == .password {
            throw Error.missingClientAuthentication
        }

        return sendOAuthRequest(grantType: grantType, parameters: parameters)
            .flatMap { [weak self] _ -> Single<Request> in
                guard let self = self else {
                    return Single<Request>.never()
                }
                return try self._authorizeOAuth(request: request, grantType: grantType)
            }
    }

    func sendOAuthRequest(grantType: OAuthenticationGrantType, parameters: Parameters? = nil) -> Single<Void> {
        var parameters = parameters ?? [:]
        parameters["grant_type"] = grantType.rawValue

        let request = Request {
            $0.path = client.config.oauthEndpointPath
            $0.httpMethod = .post
            $0.encoding = URLEncoding.default
            $0.authentication = .client
            $0.parameters = parameters
            $0.loggingOption = LoggingOption(request: [
                "password": .masked,
                "refresh_token": .halfMasked,
                "client_secret": .halfMasked
            ], response: [
                "access_token": client.config.maskTokens ? .halfMasked : .default,
                "refresh_token": client.config.maskTokens ? .halfMasked : .default,
            ])

        }

        isAuthenticating = true

        return client.request(request).flatMap { [weak self, client] json in
            let accessToken = try json.map(to: AccessToken.self)
            accessToken.host = (request.host ?? client?.config.host) ?? ""
            accessToken.grantType = grantType
            accessToken.store()
            client?.logger?.debug("Store access-token: \(optionalDescription(accessToken))")
            client?.authorizationGrantTypeSubject.onNext(accessToken.grantType)
            self?.isAuthenticating = false
            return Single<Void>.just(())

        }.catchError { [weak self, client] error -> Single<Void> in
            defer {
                self?.isAuthenticating = false
            }
            guard error == Error.invalidGrant, grantType == .refreshToken else {
                throw error
            }

            // If the server responds with 'invalid_grant' for a refresh_token granType
            // then the refresh-token is invalid and therefor the access-token is too.
            // So we can completely remove the access-token, since it is in no way able to revalidate.
            client?.logger?.warning("Clearing access-token; invalid refresh-token")
            client?.clearAccessToken()
            throw Error.refreshTokenInvalidated
        }
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
        client.authorizationGrantTypeSubject.onNext(grantType)
    }

    // MARK: - Recover
    // --------------------------------------------------------

    func recover(from error: Swift.Error, request: Request) throws -> Single<JSON> {
        // If we receive an 'invalid_grant' error and we tried to do a refresh_token authentication
        // The access-token and underlying refresh-token is invalid
        // So we can revoke the access-token
        if error == Error.invalidGrant,
            case let .oauth2(grantType) = request.authentication,
            grantType != .refreshToken {

            let accessToken = AccessToken(host: (request.host ?? client.config.host) ?? "")
            if let logReq = request.loggingOption?.request?["*"], case KeyLoggingOption.ignore = logReq {
            } else {
                client.logger?.warning("Access-token expired; invalidating access-token")
            }

            accessToken.invalidate()
            return client.request(request)
        }
        throw error
    }
}
