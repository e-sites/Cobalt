//
//  Cobalt.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import RxSwift
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

    @objc
    let service = ClientService()
    
    // MARK: - Constructor
    // --------------------------------------------------------

    required public init(config: Config) {
        self.config = config
        service.logger = logger
    }

    // MARK: - Request functions
    // --------------------------------------------------------

    /// Make a request using a 'simple' `Result` handler closure
    ///
    /// - Parameters:
    ///   - `request`: The `Request` object
    ///   - `handler`: The closure to call when the request is finished
    open func request(_ request: Request, handler: @escaping ((Alamofire.Result<JSON>) -> Void)) {
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
    open func request(_ request: Request) -> Promise<JSON> {
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

    open func startRequest(_ request: Request) {

    }

    open func finishRequest(_ request: Request, response: HTTPURLResponse?) {

    }

    private func _request(_ request: Request) -> Promise<JSON> {
        let requestID = self.requestID
        self.requestID += 1
        if self.requestID == 100 {
            self.requestID = 1
        }
        var loggingOptions: [String: KeyLoggingOption] = [:]
        if config.maskTokens {
            loggingOptions["Authorization"] = .halfMasked
        }

        if !request.useHeaders.keys.isEmpty {
            let headersDictionary = dictionaryForLogging(request.useHeaders, options: loggingOptions)
            logger?.verbose("#\(requestID) Headers: \(headersDictionary ?? [:])")
        }

        let loggingParameters = dictionaryForLogging(request.parameters,
                                                     options: request.loggingOption?.request)

        logger?.request("#\(requestID) " + request.httpMethod.rawValue,
                        request.urlString,
                        loggingParameters?.flatJSONString ?? "")
        startRequest(request)

        service.currentRequest = request

        // Check to see if the cache engine should handle it
        if !service.shouldPerformRequestAfterCacheCheck(), let json = service.json {
            _responseParsing(json: json, request: request, requestID: requestID)
            return Promise(json)
        }

        return Promise<JSON>(on: .main) { [weak self] fulfill, reject in
            Alamofire.request(request.urlString,
                              method: request.httpMethod,
                              parameters: request.parameters,
                              encoding: request.useEncoding,
                              headers: request.useHeaders)
                .validate()
                .responseJSON { response in

                    let statusCode = response.response?.statusCode ?? 500
                    self?.finishRequest(request, response: response.response)
                    let statusString = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                    self?.logger?.verbose("#\(requestID) HTTP Status: \(statusCode) ('\(statusString)')")
                    var json: JSON?
                    if let data = response.data {
                        json = JSON(data)
                        self?.service.json = json
                        self?.service.optionallyWriteToCache()
                        self?._responseParsing(json: json, request: request, requestID: requestID)
                    }

                    if let error = response.error {
                        self?.logger?.error("#\(requestID) Original: \(error)")
                        let apiError = Error(from: error, json: json)
                        self?.logger?.error("#\(requestID) Error: \(apiError)")
                        reject(apiError)
                        return
                    }

                    guard let responseJSON = json else {
                        reject(Error.empty)
                        return
                    }

                    fulfill(responseJSON)
            }
        }
    }

    private func _responseParsing(json: JSON?, request: Request, requestID: Int) {
        let dictionary = dictionaryForLogging(json?.dictionaryObject ?? [:], options: request.loggingOption?.response)
        logger?.response("#\(requestID) " + request.httpMethod.rawValue, request.urlString, dictionary?.flatJSONString ?? "")
    }

    // MARK: - Login
    // --------------------------------------------------------

    open func login(username: String, password: String) -> Promise<Void> {
        let parameters = [
            "username": username,
            "password": password
        ]
        return authProvider.sendOAuthRequest(grantType: .password, parameters: parameters)
    }
    
    /// Handle the result of a manual login call
    ///
    /// - Parameters:
    ///     - grantType: `OAuthenticationGrantType`
    ///     - accessToken: `String`
    ///     - refreshToken: `OAuthenticationGrantType`
    ///     - expiresIn: `Int`
    ///     - host: `String?`
    ///
    /// - Returns: `Void`
    public func loggedIn(grantType: OAuthenticationGrantType,
                         accessToken: String,
                         refreshToken: String,
                         expireDate: Date) {
        guard let host = config.host else {
            fatalError("No valid host set in the config")
        }
        
        authProvider.handleManualOAuthRequest(grantType: grantType, accessToken: accessToken, refreshToken: refreshToken, expireDate: expireDate, host: host)
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
    func dictionaryForLogging(_ parameters: [String: Any]?,
                              options: [String: KeyLoggingOption]?) -> [String: Any]? {
        guard let theParameters = parameters, let options = options else {
            return parameters
        }
        return _mask(parameters: theParameters, options: options)
    }

    fileprivate func _mask(parameters: [String: Any],
                           options: [String: KeyLoggingOption],
                           path: String = "") -> [String: Any] {
        var logParameters: [String: Any] = [:]
        for (key, value) in parameters {
            let type = options["\(path)\(key)"] ?? .default
            if let dictionary = value as? [String: Any], case KeyLoggingOption.default = type {
                logParameters[key] = _mask(parameters: dictionary, options: options, path: "\(path)\(key).")
                continue
            }
            guard let string = Client.mask(string: value, type: type) else {
                continue
            }
            logParameters[key] = string
        }
        return logParameters
    }

    class func mask(string value: Any?, type: KeyLoggingOption) -> Any? {
        guard let value = value else {
            return nil
        }
        switch type {
        case .halfMasked:
            guard let stringValue = value as? String, !stringValue.isEmpty else {
                return value
            }
            let length = Int(floor(Double(stringValue.count) / 2.0))
            let startIndex = stringValue.startIndex
            let midIndex = stringValue.index(startIndex, offsetBy: length)
            return String(describing: stringValue[startIndex..<midIndex]) + "***"

        case .ignore:
            return nil

        case .replaced(let string):
            return string

        case .masked:
            return "***"

        case .shortened:
            guard let stringValue = value as? String else {
                fallthrough
            }
            if stringValue.count > 128 {
                let startIndex = stringValue.startIndex
                let endIndex = stringValue.index(startIndex, offsetBy: 128)
                return String(describing: stringValue[startIndex..<endIndex]) + "..."
            } else {
                return value
            }
            
        default:
            return value
        }
    }
}

extension Reactive where Base: Client {
    public var authorizationGrantType: Observable<OAuthenticationGrantType?> {
        return base.authorizationGrantTypeSubject.distinctUntilChanged().asObservable()
    }
}
