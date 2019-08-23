//
//  CobaltTests-Cache.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//


import Foundation
import XCTest
import Nimble
import Promises
import Alamofire
import Foundation
@testable import Cobalt

class CobaltTestsCache: CobaltTests {
    func testCache() {
        client.cache.clear()

        waitUntil { done in
            let request = Request {
                $0.cachePolicy = .expires(seconds: 10)
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                        let request = Request {
                            $0.cachePolicy = .expires(seconds: 10)
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
        }
    }

    func testNoCache() {
        client.cache.clear()

        waitUntil { done in
            let request = Request {
                $0.cachePolicy = .expires(seconds: 10)
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
                    let request = Request {
                        $0.cachePolicy = .expires(seconds: 10)
                        $0.authentication = .client
                        $0.path = "/api/users"
                        $0.parameters = [
                            "per_page": 5
                        ]
                    }

                    self.client.request(request)
                    .then { json in
                        expect(json["data"].arrayValue.count) == 5
                    }.catch { error in
                        XCTAssert(false, "\(error)")
                    }.always {
                        done()
                    }
            }
        }
    }
}
