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
import RxSwift
import RxCocoa
@testable import Cobalt

class CobaltTests: XCTestCase {
    lazy var disposeBag = DisposeBag()
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
        Nimble.AsyncDefaults.timeout = .seconds(15)
        Nimble.AsyncDefaults.pollInterval = .milliseconds(100)
    }
    
    override func tearDown() {
        super.tearDown()
    }
}
