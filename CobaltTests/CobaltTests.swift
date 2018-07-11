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
    lazy var config = APIConfig {
        $0.clientID = "id"
        $0.clientSecret = "secret"
        $0.host = "https://reqres.in"
        $0.logger = TestLogger()
    }
    lazy var client = Cobalt(config: self.config)

    override func setUp() {
        super.setUp()
        Nimble.AsyncDefaults.Timeout = 15
        Nimble.AsyncDefaults.PollInterval = 0.1
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testRequestGET() {
        waitUntil { done in
            let request = APIRequest {
                $0.path = "/api/users"
                $0.parameters = [
                    "per_page": 10
                ]
            }

            self.client.request(request)
            .then { json in
                   expect(json["data"].arrayValue.count) == 10
            }.catch { error in
                XCTAssert(false, "\(error)")
            }.always {
                done()
            }
        }
    }

    func testRequestGET404() {
        waitUntil { done in
            let request = APIRequest {
                $0.path = "/some_strange_request"
            }

            self.client.request(request).then { json in
                XCTAssert(false, "Should not get here")
            }.catch { error in
                if !(error is APIError) {
                    XCTAssert(false, "Expect to be a APIError, got: \(error)")
                    return
                }
                let apiError = error as! APIError
                if let underlyingError = apiError.underlyingError {
                    if !(underlyingError is AFError) {
                        XCTAssert(false, "Expect to be a underlying AFError, got: \(underlyingError)")
                        return
                    }
                    expect((underlyingError as! AFError).responseCode) == 404
                } else {
                    XCTAssert(false, "Expect to have error 404, got \(apiError)")
                }

            }.always {
                done()
            }
        }
    }
}
