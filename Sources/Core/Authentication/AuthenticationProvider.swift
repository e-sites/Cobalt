//
//  AuthenticationProvider.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Alamofire
import Promises
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
    func authorize(request: Request) throws -> Promise<Request> {
        // Define headers
        var headers = request.headers ?? [:]

        // How should the request be authorized?
        switch request.authentication {

        // Regular client_id / client_secret
        // Just add an `Authorization` header
        case .client:
            guard let base64 = client.config.authorizationBasicBase64 else {
                throw Error.missingClientAuthentication
            }

            headers["Authorization"] = "Basic \(base64)"

        // If the client requires an OAuth2 authorization;
        // continue to `_authorizeOAuth(request:, grantType:)`
        case .oauth2(let grantType):
            return try _authorizeOAuth(request: request, grantType: grantType)

        default:
            break
        }

        request.useHeaders = headers
        return Promise<Request>(request)
    }

    /// Here we're going to do either of the following:
    ///
    /// 1. If the user has a valid access-token and it's not expired, use it.
    /// 2. If the user has an expired `password` access-token, refresh it
    /// 3. If you need a `client_credentials` grantType and the access-token is expired. Create a new one
    private func _authorizeOAuth(request: Request,
                                 grantType: OAuthenticationGrantType) throws -> Promise<Request> {
        var parameters: Parameters = [:]
        var grantType = grantType

        let host = (request.host ?? self.client.config.host) ?? ""
        if let accessTokenObj = AccessToken.get(host: host, grantType: grantType),
            let accessToken = accessTokenObj.accessToken {

            if !accessTokenObj.isExpired {
                let expiresIn = Int((accessTokenObj.expireDate ?? Date()).timeIntervalSinceNow)
                client.logger?.verbose("[?] Access token expires in: \(expiresIn)s")
                request.useHeaders["Authorization"] = "Bearer " + accessToken
                return Promise<Request>(request)
            }

            client.logger?.warning("Access-token expired, refreshing ...")
            if grantType == .password, let refreshToken = accessTokenObj.refreshToken {
                grantType = .refreshToken
                parameters["refresh_token"] = refreshToken
            }
        }

        if grantType == .password {
            throw Error.missingClientAuthentication
        }

        return sendOAuthRequest(grantType: grantType,parameters: parameters).then { _ in
            return try self._authorizeOAuth(request: request, grantType: grantType)
        }
    }

    func sendOAuthRequest(grantType: OAuthenticationGrantType, parameters: Parameters? = nil) -> Promise<Void> {
        var parameters = parameters ?? [:]
        parameters["grant_type"] = grantType.rawValue

        let request = Request {
            $0.path = client.config.oauthEndpointPath
            $0.httpMethod = .post
            $0.encoding = URLEncoding.default
            $0.authentication = .client
            $0.parameters = parameters
            $0.parametersLoggingOptions = [
                "password": .masked,
                "refresh_token": .halfMasked
            ]
        }

        isAuthenticating = true

        return client.request(request).then { json in
            let accessToken = try json.map(to: AccessToken.self)
            accessToken.host = (request.host ?? self.client.config.host) ?? ""
            accessToken.grantType = grantType
            accessToken.store()
            self.client.logger?.debug("Store access-token: \(optionalDescription(accessToken))")
            self.client.authorizationGrantTypeSubject.onNext(accessToken.grantType)
            return Promise<Void>(())

        }.recover { error -> Promise<Void> in

            guard error == Error.invalidGrant, grantType == .refreshToken else {
                throw error
            }

            // If the server responds with 'invalid_grant' for a refresh_token granType
            // then the refresh-token is invalid and therefor the access-token is too.
            // So we can completely remove the access-token, since it is in no way able to revalidate.
            self.client.logger?.warning("Clearing access-token; invalid refresh-token")
            self.client.clearAccessToken()
            throw Error.refreshTokenInvalidated
        }.always {
            self.isAuthenticating = false
        }
    }

    // MARK: - Recover
    // --------------------------------------------------------

    func recover(from error: Swift.Error, request: Request) throws -> Promise<JSON> {
        // If we receive an 'invalid_grant' error and we tried to do a refresh_token authentication
        // The access-token and underlying refresh-token is invalid
        // So we can revoke the access-token
        if error == Error.invalidGrant,
            case let .oauth2(grantType) = request.authentication,
            grantType != .refreshToken {

            let accessToken = AccessToken(host: (request.host ?? self.client.config.host) ?? "")
            self.client.logger?.warning("Access-token expired; invalidating access-token")
            accessToken.invalidate()
            return self.client.request(request)
        }
        throw error
    }
}
