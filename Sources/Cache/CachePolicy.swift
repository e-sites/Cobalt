//
//  CachePolicy.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation

/// The (local) caching policy for the request
public enum CachePolicy {

    /// Do not cache the response
    case never

    /// Cache the response for a 'x' seconds
    case expires(seconds: TimeInterval)

    init(rawValue: String) {
        let split = rawValue.components(separatedBy: ":")
        if split.count == 2 {
            switch split[0] {
            case "expires":
                if let time = TimeInterval(split[1]) {
                    self = .expires(seconds: time)
                    return
                }
            default:
                break
            }
        }
        self = .never
    }

    var rawValue: String {
        switch self {
        case .never:
            return "never"

        case .expires(let time):
            return "expires:\(time)"
        }
    }
}
