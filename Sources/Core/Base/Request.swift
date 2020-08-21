//
//  Request.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation

public class Request {
    public enum ParameterEncoding: String {
        case queryString
        case json
        case url
        case methodDependent
    }
    
    public enum HTTPMethod: String {
        case connect = "CONNECT"
        case delete = "DELETE"
        case get = "GET"
        case head = "HEAD"
        case options = "OPTIONS"
        case patch = "PATCH"
        case post = "POST"
        case put = "PUT"
        case trace = "TRACE"
    }
    fileprivate let uuid = UUID().uuidString

    public var path: String = "/"
    public var host: String?
    public var httpMethod: HTTPMethod = .get
    public var parameters: [String: Any]?
    public var headers: [String: String?]?
    public var encoding: ParameterEncoding = ParameterEncoding.methodDependent
    public var authentication: Authentication = .none
    public var loggingOption: LoggingOption?

    @available(*, deprecated, renamed: "loggingOption")
    public var parametersLoggingOptions: [String: Any]?

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
        return "<Request> [ uuid: \(uuid), " +
            "path: \(path), " +
            "httpMethod: \(httpMethod), " +
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


extension Request {
    func addHeader(_ key: String, value: String?) {
        if headers == nil {
            headers = [:]
        }
        headers?[key] = value
    }
    
    func urlRequest() -> URLRequest? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = httpMethod.rawValue
        
        var encoding = self.encoding
        if encoding == .methodDependent {
            switch httpMethod {
            case .get, .delete, .head:
                encoding = .queryString
            default:
                encoding = .json
            }
        }
        switch encoding {
        case .json:
            addHeader("Content-Type", value: "application/json")
            if let parameters = parameters, let data = try? JSONSerialization.data(withJSONObject: parameters, options: []) {
                urlRequest.httpBody = data
            }
        case .queryString:
            if let parameters = parameters, !parameters.isEmpty {
                var additionalQueryParameters = ""
                for (key, value) in parameters {
                    if additionalQueryParameters.isEmpty && (url.query == nil || url.query?.isEmpty == true) {
                        additionalQueryParameters = "?"
                    } else {
                        additionalQueryParameters += "&"
                    }
                    let stringValue = String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
                    additionalQueryParameters += "\(key)=\(stringValue)"
                }
                urlRequest.url = URL(string: urlString + additionalQueryParameters)!
            }
        default:
            break
        }
            
        for (key, value) in headers ?? [:] {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        return urlRequest
    }
}
