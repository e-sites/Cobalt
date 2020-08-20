//
//  CobaltTests-Requests.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 12/07/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import XCTest
import Nimble
import Alamofire
import Foundation
import Combine
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

            self.client.request(request).sink(receiveCompletion: { event in
                switch event {
                case .finished:
                    break
                case .failure(let error):
                    XCTAssert(false, "\(error)")
                }
                done()
            }, receiveValue: { response in
                if let dictionary = response as? [String: Any], let data = dictionary["data"] as? [Any] {
                    expect(data.count) == 10
                } else {
                    XCTAssert(false, "Response \(response) is not a dictionary")
                }
            }).store(in: &self.cancellables)
        }
    }

    func testRequestGET404() {
        waitUntil { done in
            let request = Request {
                $0.path = "/some_strange_request"
            }

            self.client.request(request).sink(receiveCompletion: { event in
                switch event {
                case .finished:
                    XCTAssert(false, "Should not get here")

                case .failure(let error):
                    if let underlyingError = error.underlyingError {
                        if !(underlyingError is AFError) {
                            XCTAssert(false, "Expect to be a underlying AFError, got: \(underlyingError)")
                            return
                        }
                        expect((underlyingError as! AFError).responseCode) == 404
                    } else {
                        XCTAssert(false, "Expect to have error 404, got \(error)")
                    }
                }
                done()
            }, receiveValue: { _ in
                XCTAssert(false, "Should not get here")
            }).store(in: &self.cancellables)
        }
    }
}
