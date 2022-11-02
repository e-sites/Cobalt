//
//  CobaltError.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Combine
import Alamofire

public class CobaltError: Error {

    private(set) public var code: Int = 0
    private(set) public var response: CobaltResponse?
    private(set) public var message: String?
    private(set) public var underlyingError: Error?
    
    internal(set) public var request: CobaltRequest?

    public var domain: String {
        return "com.esites.Cobalt"
    }

    // MARK: - Errors
    // --------------------------------------------------------

    public static var empty: CobaltError {
        return CobaltError(code: 101)
    }

    public static var invalidGrant: CobaltError {
        return CobaltError(code: 201, message: "invalid_grant")
    }

    public static var invalidClient: CobaltError {
        return CobaltError(code: 202, message: "invalid_client")
    }
    
    public static var refreshTokenInvalidated: CobaltError {
        return CobaltError(code: 203, message: "Refresh token is invalidated")
    }

    public static var missingClientAuthentication: CobaltError {
        return CobaltError(code: 204, message: "Missing client authentication")
    }
    
    public static var invalidUrl: CobaltError {
        return CobaltError(code: 205, message: "Authorization code request url is invalid")
    }

    public static func unknown(_ response: CobaltResponse? = nil) -> CobaltError {
        return CobaltError(code: 100, response: response)
    }
    
    public static func invalidRequest(_ message: String) -> CobaltError {
        return CobaltError(code: 301, message: message)
    }
    
    public static func parse(_ message: String) -> CobaltError {
        return CobaltError(code: 801, message: message)
    }
    
    public static var concurrentAuthentication: CobaltError {
        return CobaltError(code: 401, message: "Concurrent authentication requests")
    }

    public static func underlying(_ error: Error, response: CobaltResponse? = nil) -> CobaltError {
        let apiError = CobaltError(code: 601)
        apiError.underlyingError = error
        
        if let response {
            apiError.response = response
        }
        
        return apiError
    }
    
    func set(request: CobaltRequest) -> CobaltError {
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

    init(from error: Error, response: CobaltResponse? = nil) {
        if let cobaltError = error as? CobaltError {
            _clone(from: cobaltError)
            return
        } else if let dictionary = response as? [String: Any], let errorValue = dictionary["error"] as? String {
            switch errorValue {
            case "invalid_grant":
                _clone(from: CobaltError.invalidGrant)
                return
                
            case "invalid_client":
                _clone(from: CobaltError.invalidClient)
                return
                
            default:
                break
            }
            
        } else if let afError = underlyingError as? AFError,
                  case let .responseSerializationFailed(reason) = afError,
                  case .inputDataNilOrZeroLength = reason {
            _clone(from: CobaltError.empty)
            return
        }
        
        _clone(from: CobaltError.underlying(error, response: response))
    }
    
    private func _clone(from error: CobaltError) {
        self.code = error.code
        self.message = error.message
        self.underlyingError = error.underlyingError
        self.response = error.response
        self.request = error.request
    }
}

extension CobaltError: CustomDebugStringConvertible {
    public var debugDescription: String {
        let jsonString = Helpers.dictionaryForLogging(response as? [String: Any], options: request?.loggingOption?.response)?.flatJSONString ?? response?.flatJSONString

        return "<CobaltError> [ " +
            "code: \(code), " +
            "response: \(optionalDescription(jsonString)), " +
            "message: \(optionalDescription(message)), " +
            "request: \(optionalDescription(request)), " +
            "underlying: \(optionalDescription(underlyingError)) " +
         "]"
    }
}


extension CobaltError: Equatable {
    public static func == (lhs: CobaltError, rhs: CobaltError) -> Bool {
        return lhs.code == rhs.code
    }

    public static func == (lhs: CobaltError, rhs: Error) -> Bool {
        return lhs == CobaltError(from: rhs)
    }

    public static func == (lhs: Error, rhs: CobaltError) -> Bool {
        return rhs == lhs
    }
}

extension CobaltError {
    func asPublisher<T>(outputType: T.Type) -> AnyPublisher<T, CobaltError> {
        return Fail<T, CobaltError>(error: self).eraseToAnyPublisher()
    }
}
