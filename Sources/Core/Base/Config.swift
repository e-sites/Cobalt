//
//  Config.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Logging

public class Config {
    
    public enum ClientAuthorization: String {
        case basicHeader
        case requestBody
    }
    
    public class Authentication {
        public var path = "/oauth/v2/token"
        public var authorization: Config.ClientAuthorization? = .basicHeader
        public var clientID: String?
        public var clientSecret: String?
        public var host: String?
    }
    
    public class Logging {
        public var logger: Logger?
        public var maskTokens = false
    }

    public let authentication = Authentication()
    public let logging = Logging()
    public var host: String?

    public init(_ builder: ((Config) -> Void)) {
        builder(self)
    }
}
