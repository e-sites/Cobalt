//
//  Error.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON


public class Error: Swift.Error {

    private(set) public var code: Int = 0
    private(set) public var json: JSON?
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

    public static func unknown(_ json: JSON? = nil) -> Error {
        return Error(code: 100, json: json)
    }

    public static func invalidRequest(_ message: String) -> Error {
        return Error(code: 301, message: message)
    }

    public static func underlying(_ error: Swift.Error, json: JSON? = nil) -> Error {
        let apiError = Error(code: 601)
        apiError.underlyingError = error
        
        if json != nil {
            apiError.json = json
        }
        
        return apiError
    }
    
    func set(request: Request) -> Error {
        self.request = request
        return self
    }

    // MARK: - Constructor
    // --------------------------------------------------------

    init(code: Int, json: JSON? = nil, message: String? = nil) {
        self.code = code
        self.json = json
        self.message = message
    }

    init(from error: Swift.Error, json: JSON? = nil) {
        if error is Error {
            _clone(from: error as! Error)
            return
        } else if let json = json, json != .null {
            switch json["error"].stringValue {
            case "invalid_grant":
                _clone(from: Error.invalidGrant)
                return

            case "invalid_client":
                _clone(from: Error.invalidClient)
                return

            default:
                break
            }
            
            _clone(from: Error.underlying(error, json: json))
            return
        }
        
        _clone(from: Error.underlying(error))
    }

    private func _clone(from error: Error) {
        self.code = error.code
        self.message = error.message
        self.underlyingError = error.underlyingError
        self.json = error.json
        self.request = error.request
    }
}

extension Error: CustomStringConvertible {
    public var description: String {
        var jsonString = "(nil)"
        
        if let json = self.json {
            jsonString = json.rawString(options: JSONSerialization.WritingOptions(rawValue: 0)) ?? "(nil)"
        }
        
        return "<Error> [ code: \(code), " +
            "message: \(optionalDescription(message)), " +
            "request: \(optionalDescription(request)), " +
            "json: \(optionalDescription(jsonString)), " +
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
