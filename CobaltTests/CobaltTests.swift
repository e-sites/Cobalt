//
//  CobaltTests.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 19-08-16.
//  Copyright © 2016 E-sites. All rights reserved.
//

import XCTest
import Nimble
import Promises
import Alamofire
@testable import Cobalt


class CobaltTests: XCTestCase {
    lazy var config = Config {
        $0.clientID = "id"
        $0.clientSecret = "secret"
        $0.clientAuthorization = .requestBody
        $0.host = "https://reqres.in"
        $0.logger = TestLogger()
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
