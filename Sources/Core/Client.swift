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

open class Client: ReactiveCompatible {

    // MARK: - Variables
    // --------------------------------------------------------

    fileprivate var requestID = 1

    public let config: Config

    fileprivate lazy var authProvider = AuthenticationProvider(client: self)

    fileprivate lazy var queue = RequestQueue(client: self)

    var authorizationGrantTypeSubject = BehaviorSubject<OAuthenticationGrantType?>(value: nil)

    var authorizationGrantType: OAuthenticationGrantType? {
        do {
            return try authorizationGrantTypeSubject.value()
        } catch {
            return nil
        }
    }

    public var accessToken: AccessToken? {
        guard let host = config.host else {
            return nil
        }
        return AccessToken(host: host)
    }

    var logger: Logger? {
        return config.logger
    }

    
    // MARK: - Constructor
    // --------------------------------------------------------

    required public init(config: Config) {
        self.config = config
    }

    // MARK: - Request functions
    // --------------------------------------------------------

    /// Make a request using a 'simple' `Result` handler closure
    ///
    /// - Parameters:
    ///   - `request`: The `Request` object
    ///   - `handler`: The closure to call when the request is finished

    public func request(_ request: Request, handler: @escaping ((Alamofire.Result<JSON>) -> Void)) {
        self.request(request).then { json in
            handler(.success(json))
        }.catch { error in
            handler(.failure(error))
        }
    }

    /// Make a promise requst
    ///
    /// - Parameters:
    ///   - `request`: The `Request` object
    ///
    /// - Returns: `Promise<JSON>`
    public func request(_ request: Request) -> Promise<JSON> {
        // Strip slashes to form a valid urlString
        guard var host = (request.host ?? config.host) else {
            return Promise(Error.invalidRequest("Missing 'host'"))
        }

        // If the client is authenticating with OAuth.
        // We need to wait for it to finish, and then continue with the original requests
        // So we add it to the `RequestQueue`
        if authProvider.isAuthenticating && request.requiresOAuthentication {
            queue.add(request)
            return queue.promise(of: request) ?? Promise(Error.unknown())
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

    private func _request(_ request: Request) -> Promise<JSON> {
        let requestID = self.requestID
        self.requestID += 1
        if self.requestID == 100 {
            self.requestID = 1
        }
        if !request.useHeaders.keys.isEmpty {
            logger?.verbose("#\(requestID) Headers: \(request.useHeaders)")
        }
        let loggingParameters = parametersForLogging(request.parameters,
                                                     options: request.parametersLoggingOptions)

        logger?.request("#\(requestID) " + request.httpMethod.rawValue,
                        request.urlString,
                        loggingParameters?.flatJSONString ?? "")
        
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
                let apiError = Error(from: error, json: json)
                self?.logger?.error("#\(requestID) Error: \(apiError)")
                promise.reject(apiError)
                return
            }

            guard let responseJSON = json else {
                promise.reject(Error.empty)
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
            fatalError("No host given, nor a valid host set in the Cobalt.Config")
        }
        AccessToken(host: host).clear()
    }
}

// MARK: - Helpers
// --------------------------------------------------------

extension Client {


    func parametersForLogging(_ parameters: Parameters?,
                                           options: [String: ParameterLoggingOption]?) -> Parameters? {
        var options = options ?? [:]
        guard let theParameters = parameters else {
            return parameters
        }

        options["password"] = .masked
        let logParameters = _mask(parameters: theParameters , options: options)

        return logParameters
    }

    fileprivate func _mask(parameters: Parameters,
                           options: [String: ParameterLoggingOption],
                           path: String = "") -> Parameters {
        var logParameters: Parameters = [:]
        for (key, value) in parameters {
            let type = options["\(path)\(key)"] ?? .default
            if let dictionary = value as? Parameters {
                logParameters[key] = _mask(parameters: dictionary, options: options, path: "\(path)\(key).")
                continue
            }
            switch type {
            case .ignore:
                continue
            case .masked:
                logParameters[key] = "***"
            case .shortened:
                guard let stringValue = value as? String else {
                    fallthrough
                }
                if stringValue.count > 128 {
                    let startIndex = stringValue.startIndex
                    let endIndex = stringValue.index(startIndex, offsetBy: 128)
                    logParameters[key] = String(describing: stringValue[startIndex...endIndex] + "...")
                } else {
                    logParameters[key] = value
                }
            default:
                logParameters[key] = value

            }
        }
        return logParameters
    }
}

extension Reactive where Base: Client {
    public var authorizationGrantType: Observable<OAuthenticationGrantType?> {
        return self.base.authorizationGrantTypeSubject.distinctUntilChanged().asObservable()
    }
}
