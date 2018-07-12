//
//  Cobalt.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import Promises
import SwiftyJSON
import Alamofire

open class Cobalt: ReactiveCompatible {

    // MARK: - Variables
    // --------------------------------------------------------

    fileprivate var requestID = 1

    public let config: APIConfig

    fileprivate lazy var authProvider = APIAuthenticationProvider(client: self)

    fileprivate lazy var queue = APIRequestQueue(client: self)

    var authorizationGrantTypeSubject = BehaviorSubject<APIOAuthenticationGrantType?>(value: nil)

    var authorizationGrantType: APIOAuthenticationGrantType? {
        do {
            return try authorizationGrantTypeSubject.value()
        } catch {
            return nil
        }
    }

    var logger: CobaltLogger? {
        return config.logger
    }

    
    // MARK: - Constructor
    // --------------------------------------------------------

    required public init(config: APIConfig) {
        self.config = config
    }

    // MARK: - Request functions
    // --------------------------------------------------------

    /// Make a request using a 'simple' `Result` handler closure
    ///
    /// - Parameters:
    ///   - `request`: The `APIRequest` object
    ///   - `handler`: The closure to call when the request is finished

    public func request(_ request: APIRequest, handler: @escaping ((Alamofire.Result<JSON>) -> Void)) {
        self.request(request).then { json in
            handler(.success(json))
        }.catch { error in
            handler(.failure(error))
        }
    }

    /// Make a promise requst
    ///
    /// - Parameters:
    ///   - `request`: The `APIRequest` object
    ///
    /// - Returns: `Promise<JSON>`
    public func request(_ request: APIRequest) -> Promise<JSON> {
        // Strip slashes to form a valid urlString
        guard var host = (request.host ?? config.host) else {
            return Promise(APIError.invalidRequest("Missing 'host'"))
        }

        // If the client is authenticating with OAuth.
        // We need to wait for it to finish, and then continue with the original requests
        // So we add it to the `APIRequestQueue`
        if authProvider.isAuthenticating && request.requiresOAuthentication {
            queue.add(request)
            return queue.promise(of: request) ?? Promise(APIError.unknown())
        }
        
        if host.hasSuffix("/") {
            host = String(host.dropLast())
        }
        var path = request.path
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }
        let urlString = host + "/" + path

        // Define encoding
        let encoding: ParameterEncoding
        if let requestEncoding = request.encoding {
            encoding = requestEncoding
        } else if request.httpMethod == .get {
            encoding = URLEncoding.default
        } else {
            encoding = JSONEncoding.default
        }

        request.useEncoding = encoding
        request.urlString = urlString

        // 1. We (optionally) (pre-)authorize the request
        return firstly {
            return try authProvider.authorize(request: request)

        // 2. We actually send the request with Alamofire
        }.then { newRequest in
            return self._request(newRequest)

        // 3. If for some reason an error occurs, we check with the auth-provider if we need to retry
        }.recover { error -> Promise<JSON> in
            self.queue.removeFirst()
            return try self.authProvider.recover(from: error, request: request)

        // 4. If any other requests are queued, fire up the next one
        }.always {
            // When a request is finished, no matter if its succesful or not
            // We try to clear th queue
            if request.requiresOAuthentication {
                self.queue.next()
            }
        }
    }

    private func _request(_ request: APIRequest) -> Promise<JSON> {
        let requestID = self.requestID
        self.requestID += 1
        if self.requestID == 100 {
            self.requestID = 1
        }
        if !request.useHeaders.keys.isEmpty {
            logger?.verbose("#\(requestID) Headers: \(request.useHeaders)")
        }
        logger?.request("#\(requestID) " + request.httpMethod.rawValue,
                        request.urlString,
                        _maskSecrets(parameters: request.parameters)?.flatJSONString ?? "")
        
        let promise = Promise<JSON>.pending()
        Alamofire.request(request.urlString,
                          method: request.httpMethod,
                          parameters: request.parameters,
                          encoding: request.useEncoding,
                          headers: request.useHeaders)
        .validate()
        .responseJSON { [weak self] response in

            let statusCode = response.response?.statusCode ?? 500
            let statusString = HTTPURLResponse.localizedString(forStatusCode: statusCode)
            self?.logger?.verbose("#\(requestID) HTTP Status: \(statusCode) ('\(statusString)')")
            var json: JSON?
            if let data = response.data {
                json = JSON(data)
                self?.logger?.response("#\(requestID) " + request.httpMethod.rawValue,
                                      request.urlString,
                                      json?.flatString ?? "")
            }

            if let error = response.error {
                self?.logger?.error("#\(requestID) Original: \(error)")
                let apiError = APIError(from: error, json: json)
                self?.logger?.error("#\(requestID) APIError: \(apiError)")
                promise.reject(apiError)
                return
            }

            guard let responseJSON = json else {
                promise.reject(APIError.empty)
                return
            }

            promise.fulfill(responseJSON)
        }

        return promise
    }

    // MARK: - Login
    // --------------------------------------------------------

    public func login(username: String, password: String) -> Promise<Void> {
        let parameters = [
            "username": username,
            "password": password
        ]
        return authProvider.sendOAuthRequest(grantType: .password, parameters: parameters)
    }

    public func clearAccessToken(forHost host: String? = nil) {
        authorizationGrantTypeSubject.onNext(nil)
        guard let host = (host ?? config.host) else {
            fatalError("No host given, nor a valid host set in the APIConfig")
        }
        AccessToken(host: host).clear()
    }
}

// MARK: - Helpers
// --------------------------------------------------------

extension Cobalt {

    fileprivate func _maskSecrets(parameters: Parameters?) -> Parameters? {
        guard let parameters = parameters else {
            return nil
        }
        var logParameters: Parameters = [:]

        let maskedKeys = [ "password" ]
        for (key, value) in parameters {
            if maskedKeys.contains(key) {
                logParameters[key] = "***"
            } else {
                logParameters[key] = value
            }
        }
        return logParameters
    }
}

extension Reactive where Base: Cobalt {
    public var authorizationGrantType: Observable<APIOAuthenticationGrantType?> {
        return self.base.authorizationGrantTypeSubject.distinctUntilChanged().asObservable()
    }
}
