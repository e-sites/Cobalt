//
//  APIConfig.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation

public class APIConfig {
    public var clientID: String?
    public var clientSecret: String?
    public var logger: CobaltLogger?
    public var host: String?

    var authorizationBasicBase64: String? {
        guard let id = clientID,
            let secret = clientSecret,
            let base64 = "\(id):\(secret)".data(using: .utf8)?.base64EncodedString() else {
                return nil
        }
        return base64
    }

    public init(_ builder: ((APIConfig) -> Void)) {
        builder(self)
    }
}
