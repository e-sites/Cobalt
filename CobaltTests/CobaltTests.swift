//
//  CobaltTests.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 19-08-16.
//  Copyright © 2016 E-sites. All rights reserved.
//

import XCTest
import Logging
import Alamofire
import Combine
import Nimble
@testable import Cobalt

class CobaltTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()
    lazy var config = CobaltConfig {
        $0.authentication.clientID = "id"
        $0.authentication.clientSecret = "secret"
        $0.authentication.authorization = .requestBody
        $0.logging.logger = Logger(label: "com.esites.cobalt-test")
        $0.logging.logger?.logLevel = .trace
        $0.host = "https://reqres.in"
    }
    
    lazy var client = CobaltClient(config: self.config)
    override func setUp() {
        super.setUp()
        Nimble.AsyncDefaults.timeout = .seconds(15)
        Nimble.AsyncDefaults.pollInterval = .milliseconds(100)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func waitUntil(expectedFulfillmentCount: Int = 1, _ handler: @escaping (((() -> Void)?) -> Void)) {
        let expectation = self.expectation(description: UUID().uuidString)
        expectation.expectedFulfillmentCount = expectedFulfillmentCount
        handler {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 15, handler: nil)
    }
}
