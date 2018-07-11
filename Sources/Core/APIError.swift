//
//  APIError.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

public class APIError: Error {

    private(set) public var code: Int = 0
    private(set) public var json: JSON?
    private(set) public var message: String?
    private(set) public var underlyingError: Error?

    public var domain: String {
        return "com.esites.Cobalt"
    }

    // MARK: - Errors
    // --------------------------------------------------------

    public static var empty: APIError {
        return APIError(code: 101)
    }

    public static var invalidGrant: APIError {
        return APIError(code: 201, message: "invalid_grant")
    }

    public static var invalidClient: APIError {
        return APIError(code: 202, message: "invalid_client")
    }

    public static var refreshTokenInvalidated: APIError {
        return APIError(code: 203, message: "Refresh token is invalidated")
    }

    public static var missingClientAuthentication: APIError {
        return APIError(code: 204, message: "Missing client authentication")
    }

    public static func unknown(_ json: JSON? = nil) -> APIError {
        return APIError(code: 100, json: json)
    }

    public static func invalidRequest(_ message: String) -> APIError {
        return APIError(code: 301, message: message)
    }

    public static func underlying(_ error: Error) -> APIError {
        let apiError = APIError(code: 601)
        apiError.underlyingError = error
        return apiError
    }

    // MARK: - Constructor
    // --------------------------------------------------------

    init(code: Int, json: JSON? = nil, message: String? = nil) {
        self.code = code
        self.json = json
        self.message = message
    }

    init(from error: Error, json: JSON? = nil) {
        if error is APIError {
            _clone(from: error as! APIError)

        } else if let json = json, json != .null {
            switch json["error"].stringValue {
            case "invalid_grant":
                _clone(from: APIError.invalidGrant)
                return

            case "invalid_client":
                _clone(from: APIError.invalidClient)
                return

            default:
                break
            }
            _clone(from: APIError.unknown(json))

        } else {
            _clone(from: APIError.underlying(error))
        }
    }

    private func _clone(from error: APIError) {
        self.code = error.code
        self.message = error.message
        self.underlyingError = error.underlyingError
        self.json = error.json
    }
}

extension APIError: CustomStringConvertible {
    public var description: String {
        var jsonString = "nil"
        if let json = self.json {
            jsonString = json.rawString(options: JSONSerialization.WritingOptions(rawValue: 0)) ?? "nil"
        }
        return "<APIError> [ code: \(code), " +
            "json: \(optionalDescription(jsonString)), " +
            "message: \(optionalDescription(message)), " +
            "underlying: \(optionalDescription(underlyingError)) " +
        "]"
    }
}


extension APIError: Equatable {
    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        return lhs.code == rhs.code
    }

    public static func == (lhs: APIError, rhs: Error) -> Bool {
        return lhs == APIError(from: rhs)
    }

    public static func == (lhs: Error, rhs: APIError) -> Bool {
        return rhs == lhs
    }
}
