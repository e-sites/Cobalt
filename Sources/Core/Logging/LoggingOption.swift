//
//  LoggingOption.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 31/05/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation
import DebugMasking

public class LoggingOption {
    internal(set) public var response: [String: DebugMasking.MaskOption]?
    internal(set) public var request: [String: DebugMasking.MaskOption]?
    internal(set) public var headers: [String: DebugMasking.MaskOption]?
    
    public init(
        request: [String: DebugMasking.MaskOption]? = nil,
        response: [String: DebugMasking.MaskOption]? = nil,
        headers: [String: DebugMasking.MaskOption]? = nil
    ) {
        self.request = request
        self.response = response
        self.headers = headers
    }
}

extension Dictionary where Key == String, Value == DebugMasking.MaskOption {
    var isIgnoreAll: Bool {
        if let logReq = self["*"], case DebugMasking.MaskOption.ignore = logReq {
            return true
        }
        return false
    }
}
