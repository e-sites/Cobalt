//
//  CobaltTests.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 19-08-16.
//  Copyright © 2016 E-sites. All rights reserved.
//

import XCTest
import Nimble
import Logging
import Alamofire
import Combine
@testable import Cobalt

class CobaltTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()
    lazy var config = Config {
        $0.clientID = "id"
        $0.clientSecret = "secret"
        $0.logger = Logger(label: "com.esites.cobalt-test")
        $0.logger?.logLevel = .trace
        $0.clientAuthorization = .requestBody
        $0.host = "https://reqres.in"
    }
    lazy var client = Cobalt.Client(config: self.config)

    override func setUp() {
        super.setUp()
        Nimble.AsyncDefaults.Timeout = 15
        Nimble.AsyncDefaults.PollInterval = 0.1
    }
    
    override func tearDown() {
        super.tearDown()
    }
}
