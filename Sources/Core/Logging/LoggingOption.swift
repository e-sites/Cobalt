//
//  LoggingOption.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 31/05/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation

public enum KeyLoggingOption {
    case masked
    case replaced(String)
    case halfMasked
    case shortened
    case `default`
    case ignore
}

public class LoggingOption {
    internal(set) public var response: [String: KeyLoggingOption]?
    internal(set) public var request: [String: KeyLoggingOption]?

    public init(request: [String: KeyLoggingOption]? = nil, response: [String: KeyLoggingOption]? = nil) {
        self.request = request
        self.response = response
    }
}
