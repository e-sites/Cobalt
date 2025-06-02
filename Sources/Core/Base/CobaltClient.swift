//
//  CobaltClient.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Alamofire
import Logging
import DebugMasking
import Combine

open class CobaltClient {
    
    // MARK: - Variables
    // --------------------------------------------------------
    
    fileprivate var requestID = 1
    
    fileprivate let debugMasking = DebugMasking()
    
    public let config: CobaltConfig
    
    open var session: Session = Session.default
    
    private var isAuthRequesting = false
    
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
    public let service = ClientService()
    
    // MARK: - Constructor
    // --------------------------------------------------------
    
    required public init(config: CobaltConfig) {
        self.config = config
        service.logger = config.logging.logger
    }
    
    // MARK: - Request functions
    // --------------------------------------------------------
    
    /// Make a combine request
    ///
    /// - Parameters:
    ///   - `request`: The `Request` object
    ///
    /// - Returns: `AnyPublisher<CobaltResponse, CobaltError>`
    open func request(_ request: CobaltRequest) -> AnyPublisher<CobaltResponse, CobaltError> {
        // Strip slashes to form a valid urlString
        guard let host = (request.host ?? config.host) else {
            return CobaltError.invalidRequest("Missing 'host'").asPublisher(outputType: CobaltResponse.self)
        }
        
        // If the client is authenticating with OAuth.
        // We need to wait for it to finish, and then continue with the original requests
        // So we add it to the `RequestQueue`
        if (authProvider.isAuthenticating ||
            (!config.authentication.allowConcurrentCalls && (isAuthRequesting || !queue.isEmpty))) &&
            request.requiresOAuthentication {
            queue.add(request)
            guard let publisher = queue.publisher(of: request) else {
                return CobaltError.unknown().asPublisher(outputType: CobaltResponse.self)
            }
            
            return publisher
        }
        if request.requiresOAuthentication {
            isAuthRequesting = true
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
        
        return Just(request)
            .setFailureType(to: CobaltError.self)
            .subscribe(on: DispatchQueue.main)
            .flatMap { [authProvider] aRequest in authProvider.authorize(request: aRequest) }
            .prefix(1)
        // 2. We actually send the request with Alamofire
            .flatMap { [weak self] newRequest -> AnyPublisher<CobaltResponse, CobaltError> in
                guard let strongSelf = self else {
                    return AnyPublisher<CobaltResponse, CobaltError>.never()
                }
                return strongSelf._request(newRequest)
                    .tryMap { [weak self] response -> any CobaltResponse in
                        return (try self?.tryMap(newRequest, response: response)) ?? response
                    }
                    .mapError { ($0 as? CobaltError) ?? CobaltError(from: $0) }
                    .eraseToAnyPublisher()
                // 3. If for some reason an error occurs, we check with the auth-provider if we need to retry
            }
            .catch { [queue, weak self, authProvider] error -> AnyPublisher<CobaltResponse, CobaltError> in
                return authProvider.recover(from: error, request: request)
                    .tryCatch { authError -> AnyPublisher<CobaltResponse, CobaltError> in
                        if request.requiresOAuthentication {
                            self?.isAuthRequesting = false
                            queue.next()
                        }
                        throw authError
                    }
                    .mapError { CobaltError(from: $0) }
                    .eraseToAnyPublisher()
                
                // 4. If any other requests are queued, fire up the next one
            }.flatMap { [queue, weak self] response -> AnyPublisher<CobaltResponse, CobaltError> in
                // When a request is finished, no matter if its succesful or not
                // We try to clear th queue
                if request.requiresOAuthentication {
                    self?.isAuthRequesting = false
                    queue.next()
                }
                return Just(response).setFailureType(to: CobaltError.self).eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    open func startRequest(_ request: CobaltRequest) {
        
    }
    
    open func finishRequest(_ request: CobaltRequest, response: HTTPURLResponse?) {
        
    }
    
    open func tryMap(_ request: CobaltRequest, response: any CobaltResponse) throws -> any CobaltResponse {
        return response
    }
    
    private func _request(_ request: CobaltRequest) -> AnyPublisher<CobaltResponse, CobaltError> {
        let useRequestID = requestID
        requestID += 1
        if requestID == 100 {
            requestID = 1
        }
        var loggingOptions: [String: DebugMasking.MaskOption] = request.loggingOption?.headers ?? [:]
        if config.logging.maskTokens {
            loggingOptions["Authorization"] = .halfMasked
        }
        
        let ignoreLoggingRequest = request.loggingOption?.request?.isIgnoreAll == true
        let ignoreLoggingHeaders = request.loggingOption?.headers?.isIgnoreAll == true
        let ignoreLoggingResponse = request.loggingOption?.response?.isIgnoreAll == true
        
        if !request.useHeaders.isEmpty, !ignoreLoggingHeaders {
            let headersDictionary = debugMasking.mask(dictionary: request.useHeaders.dictionary, options: loggingOptions)
            logger?.notice("#\(useRequestID) Headers: \(headersDictionary)")
        }
        
        if !ignoreLoggingRequest {
            let loggingParametersString = debugMasking.mask(
                dictionary: request.parameters ?? [:],
                options: request.loggingOption?.request ?? [:]
            ).flatJSONString ?? ""
            
            logger?.trace("[REQ] #\(useRequestID) \(request.httpMethod.rawValue) \(request.urlString) \(loggingParametersString)",  metadata: [ "tag": "api" ])
        }
        startRequest(request)
        
        service.currentRequest = request
        
        if let publisher = stub(
            request: request,
            requestID: useRequestID,
            ignoreLoggingRequest: ignoreLoggingRequest,
            ignoreLoggingResponse: ignoreLoggingResponse
        ) {
            return publisher
        }
        
        // Check to see if the cache engine should handle it
        if !service.shouldPerformRequestAfterCacheCheck(), let response = service.response {
            if !ignoreLoggingResponse {
                _responseParsing(response: response, request: request, requestID: useRequestID)
            }
            
            return Just(response).setFailureType(to: CobaltError.self).eraseToAnyPublisher()
        }
        
        let authorizationHeaderPreservingRedirectHandler: Redirector = {
            let behavior = Redirector.Behavior.modify { task, request, response in
                var redirectedRequest = request
                if let originalRequest = task.originalRequest,
                   let headers = originalRequest.allHTTPHeaderFields,
                   let authorizationHeaderValue = headers["Authorization"] {
                    redirectedRequest.setValue(authorizationHeaderValue, forHTTPHeaderField: "Authorization")
                }
                
                return redirectedRequest
            }
            return Redirector(behavior: behavior)
        }()
        
        return Deferred { [weak self, session] in
            Future { promise in
                session.request(request.generateURLRequest())
                    .redirect(using: authorizationHeaderPreservingRedirectHandler)
                    .validate()
                    .responseData { dataResponse in
                        self?.finishRequest(request, response: dataResponse.response)
                        do {
                            switch self?.handleResponse(
                                request: request,
                                requestID: useRequestID,
                                statusCode: dataResponse.response?.statusCode,
                                ignoreLoggingRequest: ignoreLoggingRequest,
                                ignoreLoggingResponse: ignoreLoggingResponse,
                                data: dataResponse.data,
                                error: dataResponse.error
                            ) {
                            case .success(let response):
                                promise(.success(response))
                            case .failure(let error):
                                promise(.failure(error))
                            default:
                                break
                            }
                        }
                    }
                
            }
        }.eraseToAnyPublisher()
    }
    
    private func stub(request: CobaltRequest, requestID useRequestID: Int, ignoreLoggingRequest: Bool, ignoreLoggingResponse: Bool) -> AnyPublisher<CobaltResponse, CobaltError>? {
        defer {
            service.stubbedPublishers.removeValue(forKey: request)
        }
        guard service.shouldStub(), let publisher = service.stubbedPublishers[request] else {
            return nil
        }
        return publisher
            .tryCatch { [weak self] error -> AnyPublisher<CobaltResponse, CobaltError> in
                switch self?.handleResponse(
                    request: request,
                    requestID: useRequestID,
                    statusCode: error.code,
                    ignoreLoggingRequest: ignoreLoggingRequest,
                    ignoreLoggingResponse: ignoreLoggingResponse,
                    data: nil,
                    error: error
                ) {
                case .failure(let newError):
                    throw newError
                default:
                    throw error
                }
            }.tryMap { [weak self] response -> CobaltResponse in
                switch self?.handleResponse(
                    request: request,
                    requestID: useRequestID,
                    statusCode: 200,
                    ignoreLoggingRequest: ignoreLoggingRequest,
                    ignoreLoggingResponse: ignoreLoggingResponse,
                    data: response.data,
                    error: nil
                ) {
                case .failure(let error):
                    throw error
                case .success(let newResponse):
                    return newResponse
                default:
                    throw CobaltError.empty
                }
            }
            .map { response in
                print("~> \(response)")
                return response
            }
            .mapError { CobaltError(from: $0) }
            .eraseToAnyPublisher()
    }
    
    private func handleResponse(
        request: CobaltRequest,
        requestID useRequestID: Int,
        statusCode: Int?,
        ignoreLoggingRequest: Bool,
        ignoreLoggingResponse: Bool,
        data: Data?,
        error: Error?
    ) -> Result<CobaltResponse, CobaltError> {
        let statusCode = statusCode ?? 500
        let statusString = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        if !ignoreLoggingResponse {
            logger?.notice("#\(useRequestID) HTTP Status: \(statusCode) ('\(statusString)')")
        }
        
        var response: CobaltResponse?
        if let data {
            response = data.asCobaltResponse()
            service.response = response
            service.optionallyWriteToCache()
            if !ignoreLoggingResponse {
                _responseParsing(response: response, request: request, requestID: useRequestID)
            }
        }
        
        if let error {
            let apiError = CobaltError(from: error, response: response).set(request: request)
            if !ignoreLoggingResponse {
                logger?.error("#\(useRequestID) Original: \(error)")
                logger?.error("#\(useRequestID) Error: \(apiError)")
            }
            return .failure(apiError)
        }
        
        guard let cobaltResponse = response else {            
            return .failure(CobaltError.empty)
        }
        return .success(cobaltResponse)
    }
    
    private func _responseParsing(response: CobaltResponse?, request: CobaltRequest, requestID useRequestID: Int) {
        var responseString: String?
        if let dictionaryObject = response as? [String: Any] {
            responseString = debugMasking.mask(dictionary: dictionaryObject, options: request.loggingOption?.response ?? [:]).flatJSONString
            
        } else {
            responseString = response?.flatJSONString
        }
        
        logger?.trace("[RES] #\(useRequestID) \(request.httpMethod.rawValue) \(request.urlString) \(responseString ?? "")", metadata: [ "tag": "api"])
    }
    
    // MARK: - Login
    // --------------------------------------------------------
    
    open func login(username: String, password: String) -> AnyPublisher<Void, CobaltError> {
        let parameters = [
            "username": username,
            "password": password
        ]
        
        return authProvider.sendOAuthRequest(grantType: .password, parameters: parameters)
    }
    
    open func startAuthorizationFlow(scope: [String], redirectUri: String) -> AnyPublisher<AuthorizationCodeRequest, CobaltError> {
        return authProvider.createAuthorizationCodeRequest(scope: scope, redirectUri: redirectUri)
    }
    
    open func requestTokenFromAuthorizationCode(initialRequest request: AuthorizationCodeRequest, code: String) -> AnyPublisher<Void, CobaltError> {
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
