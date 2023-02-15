//
//  CobaltRequest.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Alamofire
import DebugMasking

public class CobaltRequest {
    fileprivate let uuid = UUID().uuidString
    public var path: String = "/"
    public var host: String?
    public var httpMethod: HTTPMethod = .get
    public var parameters: Parameters?
    public var headers: HTTPHeaders?
    public var encoding: ParameterEncoding?
    public var body: Data?
    public var authentication: Authentication = .none
    public var loggingOption: LoggingOption?
    public var cachePolicy: URLRequest.CachePolicy?
    
    var useEncoding: ParameterEncoding = URLEncoding.default
    var useHeaders: HTTPHeaders = HTTPHeaders()
    internal(set) public var urlString: String = ""
    
    public init() {
        
    }
    
    public init(_ builder: ((CobaltRequest) -> Void)) {
        builder(self)
    }
    
    var requiresOAuthentication: Bool {
        if case .oauth2 = authentication {
            return true
        }
        return false
    }
}

extension CobaltRequest: CustomDebugStringConvertible {
    public var debugDescription: String {
        var parametersDescription = optionalDescription(nil)
        if let parameters = self.parameters {
            let dictionary = DebugMasking().mask(dictionary: parameters, options: loggingOption?.request ?? [:])
            parametersDescription = String(describing: dictionary)
        }
        return "<CobaltRequest> [ path: \(path), " +
        "httpMethod: \(httpMethod.rawValue), " +
        "parameters: \(parametersDescription), " +
        "authentication: \(authentication) ]"
    }
}

extension CobaltRequest: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
    
    public static func == (lhs: CobaltRequest, rhs: CobaltRequest) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
