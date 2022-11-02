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

public final class ClientService: NSObject {
    public internal(set) var logger: Logger?
    public internal(set) var currentRequest: CobaltRequest?
    public var response: CobaltResponse?
    public var stubbedPublisher: AnyPublisher<CobaltResponse, CobaltError>?

    override public init() {
        super.init()

        let selectors: [Selector] = [ "swizzleCache", "swizzleStubbing" ].map { Selector($0) }
        
        for selector in selectors where responds(to: selector) {
            perform(selector)
        }
    }
    
    @objc
    dynamic public func shouldStub() -> Bool {
        stubbedPublisher = nil
        return false
    }

    @objc
    dynamic public func shouldPerformRequestAfterCacheCheck() -> Bool {
        response = nil
        return true
    }

    @objc
    dynamic public func optionallyWriteToCache() {
        currentRequest = nil
        response = nil
    }
}
