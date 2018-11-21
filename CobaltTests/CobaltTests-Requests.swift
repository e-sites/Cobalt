//
//  CobaltTests-Requests.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 12/07/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import XCTest
import Nimble
import Promises
import Alamofire
import Foundation
@testable import Cobalt

class CobaltTestsRequests: CobaltTests {
    func testRequestGET() {
        waitUntil { done in
            let request = Request {
                $0.authentication = .client
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
            let request = Request {
                $0.path = "/some_strange_request"
            }

            self.client.request(request).then { json in
                XCTAssert(false, "Should not get here")
            }.catch { error in
                if !(error is Cobalt.Error) {
                    XCTAssert(false, "Expect to be a Error, got: \(error)")
                    return
                }
                let apiError = error as! Cobalt.Error
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
