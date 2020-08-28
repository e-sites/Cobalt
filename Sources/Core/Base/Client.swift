//
//  Cobalt.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Logging
import Combine

open class Client {

    // MARK: - Variables
    // --------------------------------------------------------

    fileprivate var requestID = 1

    public let config: Config

    fileprivate lazy var authProvider = AuthenticationProvider(client: self)

    fileprivate lazy var queue = RequestQueue(client: self)

    @Published public var authorizationGrantType: OAuthenticationGrantType?

    var cancellables = Set<AnyCancellable>()

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
    
    /// Make a combine request
    ///
    /// - Parameters:
    ///   - `request`: The `Request` object
    ///
    /// - Returns: `AnyPublisher<CobaltResponse, Error>`
    open func request(_ request: Request) -> AnyPublisher<CobaltResponse, Error> {
        // Strip slashes to form a valid urlString
        guard var host = (request.host ?? config.host) else {
            return Error.invalidRequest("Missing 'host'").asPublisher(outputType: CobaltResponse.self)
        }

        // If the client is authenticating with OAuth.
        // We need to wait for it to finish, and then continue with the original requests
        // So we add it to the `RequestQueue`
        if authProvider.isAuthenticating && request.requiresOAuthentication {
            queue.add(request)
            guard let publisher = queue.publisher(of: request) else {
                return Error.unknown().asPublisher(outputType: CobaltResponse.self)
            }
            
            return publisher
        }
        
        if host.hasSuffix("/") {
            host = String(host.dropLast())
        }
        var path = request.path
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }
        let urlString = host + "/" + path

        request.urlString = urlString
        
        // 1. We (optionally) (pre-)authorize the request
        return authProvider.authorize(request: request)
            
        // 2. We actually send the request with URLSession
        .flatMap { [weak self] newRequest -> AnyPublisher<CobaltResponse, Error> in
            guard let self = self else {
                return AnyPublisher<CobaltResponse, Error>.never()
            }
            return self._request(newRequest)
            
        // 3. If for some reason an error occurs, we check with the auth-provider if we need to retry
        }.catch { [queue, authProvider] error -> AnyPublisher<CobaltResponse, Error> in
            queue.removeFirst()
            return authProvider.recover(from: error, request: request)
        
        // 4. If any other requests are queued, fire up the next one
        }.flatMap { [queue] response -> AnyPublisher<CobaltResponse, Error> in
            // When a request is finished, no matter if its succesful or not
            // We try to clear th queue
            if request.requiresOAuthentication {
                queue.next()
            }
            return Just(response).setFailureType(to: Error.self).eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }

    open func startRequest(_ request: Request) {

    }

    open func finishRequest(_ request: Request, response: HTTPURLResponse?) {

    }

    private func _request(_ request: Request) -> AnyPublisher<CobaltResponse, Error> {
        let requestID = self.requestID
        self.requestID += 1
        if self.requestID == 100 {
            self.requestID = 1
        }
        var loggingOptions: [String: KeyLoggingOption] = [:]
        if config.maskTokens {
            loggingOptions["Authorization"] = .halfMasked
        }

        let ignoreLoggingRequest = request.loggingOption?.request?.isIgnoreAll == true
        let ignoreLoggingResponse = request.loggingOption?.response?.isIgnoreAll == true

        if request.headers?.isEmpty == false, !ignoreLoggingRequest {
            let headersDictionary = dictionaryForLogging(request.headers, options: loggingOptions)
            logger?.notice("#\(requestID) Headers: \(headersDictionary ?? [:])")
        }

        if !ignoreLoggingRequest {
            let loggingParameters = dictionaryForLogging(request.parameters,
                                                         options: request.loggingOption?.request)

            logger?.trace("[REQ] #\(requestID) \(request.httpMethod.rawValue) \(request.urlString) \(loggingParameters?.flatJSONString ?? "")",  metadata: [ "tag": "api" ])
        }
        startRequest(request)

        service.currentRequest = request

        // Check to see if the cache engine should handle it
        if !service.shouldPerformRequestAfterCacheCheck(), let response = service.response {
            if !ignoreLoggingResponse {
                _responseParsing(response: response, request: request, requestID: requestID)
            }
            return Just(response).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        guard let urlRequest = request.urlRequest() else {
            return Error.unknown().asPublisher(outputType: CobaltResponse.self)
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest).tryMap { [weak self] data, urlResponse -> CobaltResponse in
            let httpResponse = urlResponse as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 200
            self?.finishRequest(request, response: httpResponse)
            
            let statusString = HTTPURLResponse.localizedString(forStatusCode: statusCode)
            if !ignoreLoggingResponse {
                self?.logger?.notice("#\(requestID) HTTP Status: \(statusCode) ('\(statusString)')")
            }
            
            let response = data.asCobaltResponse()
            if statusCode < 200 || statusCode >= 300 {
                throw Error(code: statusCode, response: response, message: statusString)
            }
            
            if response == nil {
                throw Error.empty
            }
            
            self?.service.response = response
            self?.service.optionallyWriteToCache()
            if !ignoreLoggingResponse {
                self?._responseParsing(response: response, request: request, requestID: requestID)
            }
            
            return response!
        }.mapError { [weak self] error in
            let apiError = Error(from: error)
            if !ignoreLoggingResponse {
                self?.logger?.error("#\(requestID) Original: \(error)")
                self?.logger?.error("#\(requestID) Error: \(apiError)")
            }
            return apiError
        }.eraseToAnyPublisher()
    }

    private func _responseParsing(response: CobaltResponse?, request: Request, requestID: Int) {
        var responseString: String?
        if let dictionaryObject = response as? [String: Any] {
            let dictionary = dictionaryForLogging(dictionaryObject, options: request.loggingOption?.response)
            responseString = dictionary?.flatJSONString
            
        } else {
            responseString = response?.flatJSONString
        }
        
        logger?.trace("[RES] #\(requestID) \(request.httpMethod.rawValue)  \(request.urlString) \(responseString ?? "")", metadata: [ "tag": "api"])
    }

    // MARK: - Login
    // --------------------------------------------------------

    open func login(username: String, password: String) -> AnyPublisher<Void, Error> {
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
        authorizationGrantType = nil
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
            guard let string = Client.mask(value: value, type: type) else {
                continue
            }
            logParameters[key] = string
        }
        return logParameters
    }

    class func mask(value: Any, type: KeyLoggingOption) -> String? {
        switch type {
        case .halfMasked:
            guard let stringValue = value as? String, !stringValue.isEmpty else {
                return String(describing: value)
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
                return String(describing: value)
            }
            
        default:
            return String(describing: value)
        }
    }
}
