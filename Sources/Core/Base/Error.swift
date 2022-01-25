//
//  Error.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Combine

public class Error: Swift.Error {

    private(set) public var code: Int = 0
    private(set) public var response: CobaltResponse?
    private(set) public var message: String?
    private(set) public var underlyingError: Swift.Error?
    
    internal(set) public var request: Request?

    public var domain: String {
        return "com.esites.Cobalt"
    }

    // MARK: - Errors
    // --------------------------------------------------------

    public static var empty: Error {
        return Error(code: 101)
    }

    public static var invalidGrant: Error {
        return Error(code: 201, message: "invalid_grant")
    }

    public static var invalidClient: Error {
        return Error(code: 202, message: "invalid_client")
    }
    
    public static var refreshTokenInvalidated: Error {
        return Error(code: 203, message: "Refresh token is invalidated")
    }

    public static var missingClientAuthentication: Error {
        return Error(code: 204, message: "Missing client authentication")
    }
    
    public static var invalidUrl: Error {
        return Error(code: 205, message: "Authorization code request url is invalid")
    }

    public static func unknown(_ response: CobaltResponse? = nil) -> Error {
        return Error(code: 100, response: response)
    }
    
    public static func invalidRequest(_ message: String) -> Error {
        return Error(code: 301, message: message)
    }
    
    public static func parse(_ message: String) -> Error {
        return Error(code: 801, message: message)
    }
    
    public static var concurrentAuthentication: Error {
        return Error(code: 401, message: "Concurrent authentication requests")
    }

    public static func underlying(_ error: Swift.Error, response: CobaltResponse? = nil) -> Error {
        let apiError = Error(code: 601)
        apiError.underlyingError = error
        
        if response != nil {
            apiError.response = response
        }
        
        return apiError
    }
    
    func set(request: Request) -> Error {
        self.request = request
        return self
    }

    // MARK: - Constructor
    // --------------------------------------------------------

    init(code: Int, response: CobaltResponse? = nil, message: String? = nil) {
        self.code = code
        self.response = response
        self.message = message
    }

    init(from error: Swift.Error, response: CobaltResponse? = nil) {
        if let cobaltError = error as? Error {
            _clone(from: cobaltError)
            return
        } else if let dictionary = response as? [String: Any], let errorValue = dictionary["eror"] as? String {
            switch errorValue {
            case "invalid_grant":
                _clone(from: Error.invalidGrant)
                return

            case "invalid_client":
                _clone(from: Error.invalidClient)
                return

            default:
                break
            }
            
            _clone(from: Error.underlying(error, response: response))
            return
        }
        
        _clone(from: Error.underlying(error))
    }

    private func _clone(from error: Error) {
        self.code = error.code
        self.message = error.message
        self.underlyingError = error.underlyingError
        self.response = error.response
        self.request = error.request
    }
}

extension Error: CustomStringConvertible {
    public var description: String {
        let jsonString = response?.flatJSONString ?? "nil"
        
        return "<Cobalt.Error> [ code: \(code), " +
            "response: \(optionalDescription(jsonString)), " +
            "message: \(optionalDescription(message)), " +
            "request: \(optionalDescription(request)), " +
            "json: \(jsonString), " +
            "underlying: \(optionalDescription(underlyingError)) " +
         "]"
    }
}


extension Error: Equatable {
    public static func == (lhs: Error, rhs: Error) -> Bool {
        return lhs.code == rhs.code
    }

    public static func == (lhs: Error, rhs: Swift.Error) -> Bool {
        return lhs == Error(from: rhs)
    }

    public static func == (lhs: Swift.Error, rhs: Error) -> Bool {
        return rhs == lhs
    }
}

extension Error {
    func asPublisher<T>(outputType: T.Type) -> AnyPublisher<T, Error> {
        return Fail<T, Error>(error: self).eraseToAnyPublisher()
    }
}
