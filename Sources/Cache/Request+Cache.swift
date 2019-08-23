//
//  Request+Cache.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation
fileprivate var requestCachePolicyKey: UInt8 = 0

extension Request {
    public var cachePolicy: CachePolicy {
        get {
            guard let policyRawValue = objc_getAssociatedObject(self, &requestCachePolicyKey) as? String else {
                return .none
            }
            return CachePolicy(rawValue: policyRawValue)
        }

        set {
            objc_setAssociatedObject(self, &requestCachePolicyKey, newValue.rawValue, .OBJC_ASSOCIATION_COPY)
        }
    }

    var cacheKey: String {
        let string = [
            host ?? "",
            path,
            httpMethod.rawValue,
            (parameters ?? [:]).map { "\($0)=\($1)" }.sorted { $0 < $1 }.joined(separator: "")
        ].joined(separator: "~")

        return string.utf8.md5.rawValue.lowercased()
    }
}
