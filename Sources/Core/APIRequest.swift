//
//  APIRequest.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Alamofire

public class APIRequest {
    fileprivate let uuid = UUID().uuidString

    public var path: String = "/"
    public var host: String?
    public var httpMethod: HTTPMethod = .get
    public var parameters: Parameters?
    public var headers: HTTPHeaders?
    public var encoding: ParameterEncoding?
    public var authentication: APIAuthentication = .none

    var useEncoding: ParameterEncoding = URLEncoding.default
    var useHeaders: HTTPHeaders = [:]
    var urlString: String = ""

    public init(_ builder: ((APIRequest) -> Void)) {
        builder(self)
    }

    var requiresOAuthentication: Bool {
        if case .oauth2 = authentication {
            return true
        }
        return false
    }
}

extension APIRequest: CustomStringConvertible {
    public var description: String {
        return "<APIRequest> [ uuid: \(uuid), " +
            "path: \(path), " +
            "httpMethod: \(httpMethod), " +
        "authentication: \(authentication) ]"
    }
}

extension APIRequest: Hashable {

    public var hashValue: Int {
        return uuid.hashValue
    }

    public static func == (lhs: APIRequest, rhs: APIRequest) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
