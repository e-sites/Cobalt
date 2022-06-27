//
//  Cobalt.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Alamofire
import Logging
import Combine

open class Client {

    // MARK: - Variables
    // --------------------------------------------------------

    fileprivate var requestID = 1

    public let config: Config
    
    open var session: Session = Session.default

    fileprivate lazy var authProvider = AuthenticationProvider(client: self)

    fileprivate lazy var queue = RequestQueue(client: self)

    @Published public var authorizationGrantType: OAuthenticationGrantType?

    var cancellables = Set<AnyCancellable>()

    public var accessToken: AccessToken? {
        guard let host = authenticationHost else {
            return nil
        }
        return AccessToken(host: host)
    }

    var logger: Logger? {
        return config.logging.logger
    }
    
    var authenticationHost: String? {
        return config.authentication.host ?? config.host
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
        guard let host = (request.host ?? config.host) else {
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
        request.urlString = String.combined(host: host, path: request.path)
        
        // 1. We (optionally) (pre-)authorize the request
        return authProvider.authorize(request: request)
        .prefix(1)
        // 2. We actually send the request with Alamofire
        .flatMap { [weak self] newRequest -> AnyPublisher<CobaltResponse, Error> in
            guard let self = self else {
                return AnyPublisher<CobaltResponse, Error>.never()
            }
            return self._request(newRequest)
            
        // 3. If for some reason an error occurs, we check with the auth-provider if we need to retry
        }.catch { [queue, authProvider] error -> AnyPublisher<CobaltResponse, Cobalt.Error> in
            return authProvider.recover(from: error, request: request)
                .tryCatch { authError -> AnyPublisher<CobaltResponse, Cobalt.Error> in
                    if request.requiresOAuthentication {
                        queue.next()
                    }
                    throw authError
                }
                .mapError { Error(from: $0) }
                .eraseToAnyPublisher()
        
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
        var loggingOptions: [String: KeyLoggingOption] = request.loggingOption?.headers ?? [:]
        if config.logging.maskTokens {
            loggingOptions["Authorization"] = .halfMasked
        }

        let ignoreLoggingRequest = request.loggingOption?.request?.isIgnoreAll == true
        let ignoreLoggingHeaders = request.loggingOption?.headers?.isIgnoreAll == true
        let ignoreLoggingResponse = request.loggingOption?.response?.isIgnoreAll == true

        if !request.useHeaders.isEmpty, !ignoreLoggingHeaders {
            let headersDictionary = Helpers.dictionaryForLogging(request.useHeaders.dictionary, options: loggingOptions)
            logger?.notice("#\(requestID) Headers: \(headersDictionary ?? [:])")
        }

        if !ignoreLoggingRequest {
            let loggingParameters = Helpers.dictionaryForLogging(request.parameters,
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
        
        return Deferred { [weak self, logger, service, session] in
            Future { promise in
                let dataRequest: DataRequest
                if let data = request.body {
                    var urlRequest = URLRequest(url: URL(string: request.urlString)!)
                    urlRequest.httpMethod = HTTPMethod.post.rawValue
                    
                    if let cachePolicy = request.cachePolicy {
                        urlRequest.cachePolicy = cachePolicy
                    }
                    request.headers?.dictionary.forEach { key, value in
                        urlRequest.setValue(value, forHTTPHeaderField: key)
                    }
                    urlRequest.httpBody = data
                    dataRequest = session.request(urlRequest)
                } else {
                    dataRequest = session.request(request.urlString,
                                             method: request.httpMethod,
                                             parameters: request.parameters,
                                             encoding: request.useEncoding,
                                             headers: request.useHeaders)
                }
                
                dataRequest
                    .validate()
                    .responseData { dataResponse in
                        let statusCode = dataResponse.response?.statusCode ?? 500
                        self?.finishRequest(request, response: dataResponse.response)
                        let statusString = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                        if !ignoreLoggingResponse {
                            logger?.notice("#\(requestID) HTTP Status: \(statusCode) ('\(statusString)')")
                        }

                        var response: CobaltResponse?
                        if let data = dataResponse.data {
                            response = data.asCobaltResponse()
                            service.response = response
                            service.optionallyWriteToCache()
                            if !ignoreLoggingResponse {
                                self?._responseParsing(response: response, request: request, requestID: requestID)
                            }
                        }

                        if let error = dataResponse.error {
                            let apiError = Error(from: error, response: response).set(request: request)
                            if !ignoreLoggingResponse {
                                logger?.error("#\(requestID) Original: \(error)")
                                logger?.error("#\(requestID) Error: \(apiError)")
                            }
                            promise(.failure(apiError))
                            return
                        }

                        guard let cobaltResponse = response else {
                            promise(.failure(Error.empty))
                            return
                        }
                        promise(.success(cobaltResponse))
                }

            }
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
    
    open func startAuthorizationFlow(scope: [String], redirectUri: String) -> AnyPublisher<AuthorizationCodeRequest, Error> {
        return authProvider.createAuthorizationCodeRequest(scope: scope, redirectUri: redirectUri)
    }
    
    open func requestTokenFromAuthorizationCode(initialRequest request: AuthorizationCodeRequest, code: String) -> AnyPublisher<Void, Error> {
        return authProvider.requestTokenFromAuthorizationCode(initialRequest: request, code: code)
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
        guard let host = authenticationHost else {
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
