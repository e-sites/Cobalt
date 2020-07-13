//
//  CobaltTests.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 19-08-16.
//  Copyright © 2016 E-sites. All rights reserved.
//

import XCTest
import Nimble
import Alamofire
import RxSwift
import RxCocoa
@testable import Cobalt

class CobaltTests: XCTestCase {
    lazy var disposeBag = DisposeBag()
    lazy var config = Config {
        $0.clientID = "id"
        $0.clientSecret = "secret"
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
