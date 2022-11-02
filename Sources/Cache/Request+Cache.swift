//
//  Request+Cache.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation
import Cobalt
import CryptoKit

fileprivate var requestCachePolicyKey: UInt8 = 0

extension CobaltRequest {
    public var diskCachePolicy: CachePolicy {
        get {
            guard let policyRawValue = objc_getAssociatedObject(self, &requestCachePolicyKey) as? String else {
                return .never
            }
            return CachePolicy(rawValue: policyRawValue)
        }

        set {
            objc_setAssociatedObject(self, &requestCachePolicyKey, newValue.rawValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }

    var cacheKey: String {
        let string = [
            host ?? "",
            path,
            httpMethod.rawValue,
            (parameters ?? [:]).map { "\($0)=\($1)" }.sorted { $0 < $1 }.joined(separator: "")
        ]
        .joined(separator: "~")
        
        let digest = Insecure.MD5.hash(data: string.data(using: .utf8) ?? Data())
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
}
