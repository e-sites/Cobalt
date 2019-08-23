//
//  ClientService.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation
import SwiftyJSON

class ClientService: NSObject {
    var logger: Logger?

    var currentRequest: Request?
    var json: JSON?

    override init() {
        super.init()

        let selectors: [Selector] = [ "swizzleCache" ].map { Selector($0) }
        
        for selector in selectors {
            if responds(to: selector) {
                perform(selector)
            }
        }
    }

    @objc
    dynamic func shouldPerformRequestAfterCacheCheck() -> Bool {
        json = nil
        return true
    }

    @objc
    dynamic func optionallyWriteToCache() {
        currentRequest = nil
        json = nil
    }
}
