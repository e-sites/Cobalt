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
import RxSwift
import RxCocoa
@testable import Cobalt

class CobaltTests: XCTestCase {
    lazy var disposeBag = DisposeBag()
    lazy var config = Config {
        $0.authentication.clientID = "id"
        $0.authentication.clientSecret = "secret"
        $0.authentication.authorization = .requestBody
        $0.logging.logger = Logger(label: "com.esites.cobalt-test")
        $0.logging.logger?.logLevel = .trace
        
        $0.host = "https://reqres.in"
    }
    lazy var client = Cobalt.Client(config: self.config)
    
    override func tearDown() {
        super.tearDown()
    }
    
    func waitUntil(_ handler: @escaping (((() -> Void)?) -> Void)) {
        let expectation = self.expectation(description: "test")
        handler({ expectation.fulfill() })
        waitForExpectations(timeout: 15, handler: nil)
    }
}
