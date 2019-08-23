//
//  Client+Cache.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation

extension Client {
    /// The CacheManager
    public var cache: CacheManager {
        return service.cacheManager
    }
}
