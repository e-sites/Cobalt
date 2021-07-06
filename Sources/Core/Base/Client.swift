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
import SwiftyJSON
import Alamofire
import Logging

open class Client: ReactiveCompatible {

    // MARK: - Variables
    // --------------------------------------------------------

    fileprivate var requestID = 1

    public let config: Config

    fileprivate lazy var authProvider = AuthenticationProvider(client: self)

    fileprivate lazy var queue = RequestQueue(client: self)

    lazy var authorizationGrantTypeSubject: BehaviorSubject<OAuthenticationGrantType?> = {
        var value: OAuthenticationGrantType?
        if let grantTypeRawValue = UserDefaults.standard.string(forKey: "OAuthenticationGrantType"),
            let grantType = OAuthenticationGrantType(rawValue: grantTypeRawValue) {
            value = grantType
        }
        
        return BehaviorSubject<OAuthenticationGrantType?>(value: value)
    }()

    private let disposeBag = DisposeBag()

    var authorizationGrantType: OAuthenticationGrantType? {
        do {
            return try authorizationGrantTypeSubject.value()
        } catch {
            return nil
        }
    }

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
        
        authorizationGrantTypeSubject.subscribe(onNext: { grantType in
            UserDefaults.standard.set(grantType?.rawValue, forKey: "OAuthenticationGrantType")
            _ = UserDefaults.standard.synchronize()
        }).disposed(by: disposeBag)
    }

    // MARK: - Request functions
    // --------------------------------------------------------

    /// Make a request using a 'simple' `Result` handler closure
    ///
    /// - Parameters:
    ///   - `request`: The `Request` object
    ///   - `handler`: The closure to call when the request is finished
    open func request(_ request: Request, handler: @escaping ((Result<JSON, Swift.Error>) -> Void)) {
        self.request(request).subscribe(onSuccess: { json in
            handler(.success(json))
        }, onError: { error in
            handler(.failure(error))
        }).disposed(by: disposeBag)
    }

    /// Make a promise requst
    ///
    /// - Parameters:
    ///   - `request`: The `Request` object
    ///
    /// - Returns: `Promise<JSON>`
    open func request(_ request: Request) -> Single<JSON> {
        // Strip slashes to form a valid urlString
        guard var host = (request.host ?? config.host) else {
            return Single<JSON>.error(Error.invalidRequest("Missing 'host'").set(request: request))
        }

        // If the client is authenticating with OAuth.
        // We need to wait for it to finish, and then continue with the original requests
        // So we add it to the `RequestQueue`
        if authProvider.isAuthenticating && request.requiresOAuthentication {
            queue.add(request)
            return queue.single(of: request) ?? Single<JSON>.error(Error.unknown().set(request: request))
        }
        
        let urlString = String.combined(host: host, path: request.path)

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
        return Single<Void>.just(()).flatMap { [authProvider] in 
            return try authProvider.authorize(request: request)

        // 2. We actually send the request with Alamofire
        }.flatMap { [weak self] newRequest in
            guard let self = self else {
                return Single<JSON>.never()
            }
            return self._request(newRequest)

        // 3. If for some reason an error occurs, we check with the auth-provider if we need to retry
        }.catchError { [weak self, authProvider] error -> Single<JSON> in
            self?.queue.removeFirst()
            return try authProvider.recover(from: error, request: request)

        // 4. If any other requests are queued, fire up the next one
        }.flatMap { [queue] json -> Single<JSON> in
            // When a request is finished, no matter if its succesful or not
            // We try to clear th queue
            if request.requiresOAuthentication {
                queue.next()
            }
            return Single.just(json)
        }
    }

    open func startRequest(_ request: Request) {

    }

    open func finishRequest(_ request: Request, response: HTTPURLResponse?) {

    }

    private func _request(_ request: Request) -> Single<JSON> {
        let requestID = self.requestID
        self.requestID += 1
        if self.requestID == 100 {
            self.requestID = 1
        }
        var loggingOptions: [String: KeyLoggingOption] = [:]
        if config.logging.maskTokens {
            loggingOptions["Authorization"] = .halfMasked
        }

        let ignoreLoggingRequest: Bool
        if let logReq = request.loggingOption?.request?["*"], case KeyLoggingOption.ignore = logReq {
            ignoreLoggingRequest = true
        } else {
            ignoreLoggingRequest = false
        }

        let ignoreLoggingResponse: Bool
        if let logRes = request.loggingOption?.response?["*"], case KeyLoggingOption.ignore = logRes {
            ignoreLoggingResponse = true
        } else {
            ignoreLoggingResponse = false
        }

        if !request.useHeaders.isEmpty, !ignoreLoggingRequest {
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
        if !service.shouldPerformRequestAfterCacheCheck(), let json = service.json {
            if !ignoreLoggingResponse {
                _responseParsing(json: json, request: request, requestID: requestID)
            }
            return Single<JSON>.just(json)
        }

        return Single<JSON>.create { [weak self] observer in
            AF.request(request.urlString,
                              method: request.httpMethod,
                              parameters: request.parameters,
                              encoding: request.useEncoding,
                              headers: request.useHeaders)
                .validate()
                .responseJSON { response in
                    let statusCode = response.response?.statusCode ?? 500
                    self?.finishRequest(request, response: response.response)
                    let statusString = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                    if !ignoreLoggingResponse {
                        self?.logger?.notice("#\(requestID) HTTP Status: \(statusCode) ('\(statusString)')")
                    }

                    var json: JSON?
                    if let data = response.data {
                        json = JSON(data)
                        self?.service.json = json
                        self?.service.optionallyWriteToCache()
                        if !ignoreLoggingResponse {
                            self?._responseParsing(json: json, request: request, requestID: requestID)
                        }
                    }

                    if let error = response.error {
                        let apiError = Error(from: error, json: json).set(request: request)
                        if !ignoreLoggingResponse {
                            self?.logger?.error("#\(requestID) Original: \(error)")
                            self?.logger?.error("#\(requestID) Error: \(apiError)")
                        }
                        observer(.error(apiError))
                        return
                    }

                    guard let responseJSON = json else {
                        observer(.error(Error.empty.set(request: request)))
                        return
                    }
                    observer(.success(responseJSON))
            }
            return Disposables.create()
        }
    }

    private func _responseParsing(json: JSON?, request: Request, requestID: Int) {
        var responseString: String?
        if let dictionaryObject = json?.dictionaryObject {
            let dictionary = Helpers.dictionaryForLogging(dictionaryObject, options: request.loggingOption?.response)
            responseString = dictionary?.flatJSONString
            
        } else {
            responseString = json?.flatString
        }
        
        logger?.trace("[RES] #\(requestID) \(request.httpMethod.rawValue)  \(request.urlString) \(responseString ?? "")", metadata: [ "tag": "api"])
    }

    // MARK: - Login
    // --------------------------------------------------------

    open func login(username: String, password: String) -> Single<Void> {
        let parameters = [
            "username": username,
            "password": password
        ]
        return authProvider.sendOAuthRequest(grantType: .password, parameters: parameters)
    }
    
    open func startAuthorizationFlow(scope: [String], redirectUri: String) -> Single<AuthorizationCodeRequest> {
        return authProvider.createAuthorizationCodeRequest(scope: scope, redirectUri: redirectUri)
    }
    
    open func requestTokenFromAuthorizationCode(initialRequest request: AuthorizationCodeRequest, code: String) -> Single<Void> {
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
        authorizationGrantTypeSubject.onNext(nil)
        guard let host = (host ?? authenticationHost) else {
            fatalError("No host given, nor a valid host set in the Cobalt.Config")
        }
        AccessToken(host: host).clear()
    }
}

// MARK: - Helpers
// --------------------------------------------------------

extension Reactive where Base: Client {
    public var authorizationGrantType: Observable<OAuthenticationGrantType?> {
        return base.authorizationGrantTypeSubject.distinctUntilChanged().asObservable()
    }
}
