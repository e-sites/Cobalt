//
//  Request.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Alamofire

public class Request {
    fileprivate let uuid = UUID().uuidString

    public var path: String = "/"
    public var host: String?
    public var httpMethod: HTTPMethod = .get
    public var parameters: Parameters?
    public var headers: HTTPHeaders?
    public var encoding: ParameterEncoding?
    public var authentication: Authentication = .none
    public var loggingOption: LoggingOption?

    @available(*, deprecated, renamed: "loggingOption")
    public var parametersLoggingOptions: [String: Any]?

    var useEncoding: ParameterEncoding = URLEncoding.default
    var useHeaders: HTTPHeaders = HTTPHeaders()
    internal(set) public var urlString: String = ""

    public init() {

    }

    public init(_ builder: ((Request) -> Void)) {
        builder(self)
    }

    var requiresOAuthentication: Bool {
        if case .oauth2 = authentication {
            return true
        }
        return false
    }
}

extension Request: CustomStringConvertible {
    public var description: String {
        return "<Request> [ path: \(path), " +
            "httpMethod: \(httpMethod.rawValue), " +
            "parameters: \(optionalDescription(parameters)), " +
        "authentication: \(authentication) ]"
    }
}

extension Request: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }

    public static func == (lhs: Request, rhs: Request) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
