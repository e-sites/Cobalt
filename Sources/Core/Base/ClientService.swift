//
//  ClientService.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation
import Logging
import Combine

class ClientService: NSObject {
    var logger: Logger?

    var currentRequest: Request?
    var response: CobaltResponse?
    var stubbedPublisher: AnyPublisher<CobaltResponse, Error>?

    override init() {
        super.init()

        let selectors: [Selector] = [ "swizzleCache", "swizzleStubbing" ].map { Selector($0) }
        
        for selector in selectors where responds(to: selector) {
            perform(selector)
        }
    }
    
    @objc
    dynamic func shouldStub() -> Bool {
        stubbedPublisher = nil
        return false
    }

    @objc
    dynamic func shouldPerformRequestAfterCacheCheck() -> Bool {
        response = nil
        return true
    }

    @objc
    dynamic func optionallyWriteToCache() {
        currentRequest = nil
        response = nil
    }
}
