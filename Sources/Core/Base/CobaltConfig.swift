//
//  CobaltConfig.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Logging
import Alamofire

public class CobaltConfig {
    
    public enum ClientAuthorization: String {
        case basicHeader
        case requestBody
    }
    
    public class Authentication {
        public var path = "/oauth/v2/token"
        public var refreshTokenPath: String?
        public var authorizationPath = "/oauth/v2/authorize"
        public var authorization: CobaltConfig.ClientAuthorization? = .basicHeader
        public var encoding: ParameterEncoding?
        public var clientID: String?
        public var clientSecret: String?
        public var host: String?
        public var pkceEnabled: Bool = false
        public var allowConcurrentCalls = true
    }
    
    public class Logging {
        public var logger: Logger?
        public var maskTokens = false
    }

    public let authentication = Authentication()
    public let logging = Logging()
    public var host: String?

    public init(_ builder: ((CobaltConfig) -> Void)) {
        builder(self)
    }
}
