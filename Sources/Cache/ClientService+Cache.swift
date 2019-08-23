//
//  ClientService+Cache.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation
import SwiftyJSON

fileprivate var _swizzled = false
fileprivate var cacheManagerKey: UInt8 = 0

extension ClientService {
    
    @objc
    func swizzleCache() {
        if _swizzled {
            return
        }
        _swizzled = true

        if let originalMethod = class_getInstanceMethod(object_getClass(self), #selector(shouldPerformRequestAfterCacheCheck)),
            let swizzledMethod = class_getInstanceMethod(object_getClass(self), #selector(swizzledShouldPerformRequestAfterCacheCheck)) {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }

        if let originalMethod = class_getInstanceMethod(object_getClass(self), #selector(optionallyWriteToCache)),
            let swizzledMethod = class_getInstanceMethod(object_getClass(self), #selector(swizzledOptionallyWriteToCache)) {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    var cacheManager: CacheManager {
        guard let getAss = objc_getAssociatedObject(self, &cacheManagerKey) as? CacheManager else {
            let cacheManager = CacheManager()
            objc_setAssociatedObject(self, &cacheManagerKey, cacheManager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return cacheManager
        }

        return getAss
    }

    @objc
    dynamic func swizzledShouldPerformRequestAfterCacheCheck() -> Bool {
        _ = swizzledShouldPerformRequestAfterCacheCheck()

        guard let request = currentRequest,
            let cachedJSON = cacheManager.getCachedJSON(for: request) else {
            return true
        }

        logger?.debug("Retrieving from cache...")
        self.json = cachedJSON
        return false
    }

    @objc
    dynamic func swizzledOptionallyWriteToCache() {
        defer {
            swizzledOptionallyWriteToCache()
        }
        guard let json = self.json, let request = currentRequest else {
            return
        }
        cacheManager.write(request: request, response: json)
    }
}
