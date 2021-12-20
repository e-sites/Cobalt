//
//  CobaltTests-Requests.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 12/07/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import XCTest
import RxSwift
import RxCocoa
import Alamofire
import Foundation
@testable import Cobalt

class CobaltTestsRequests: CobaltTests {
    func testRequestQueue() {
        waitUntil(expectedFulfillmentCount: 2) { done in
            
            let accessToken = AccessToken(host: self.config.host!)
            accessToken.accessToken = "access_token1"
            accessToken.expireDate = Date(timeIntervalSinceNow: 10)
            accessToken.grantType = .clientCredentials
            accessToken.store()
            
            let request1 = Request {
                $0.authentication = .client
                $0.path = "/some_strange_request"
                $0.authentication = .oauth2(.clientCredentials)
            }

            self.client.request(request1).subscribe { event in
                switch event {
                case .success:
                    XCTAssert(false, "Should not get here")

                case .failure:
                    break
                }
                done?()
            }.disposed(by: self.disposeBag)
            
            let request2 = Request {
                $0.authentication = .client
                $0.path = "/api/users"
                $0.parameters = [
                    "per_page": 10
                ]
                $0.authentication = .oauth2(.clientCredentials)
            }

            self.client.request(request2).subscribe { event in
                switch event {
                case .success(let json):
                    XCTAssert(json["data"].arrayValue.count == 10)

                case .failure(let error):
                    XCTAssert(false, "\(error)")
                }
                done?()
            }.disposed(by: self.disposeBag)
        }
    }
    
    
    func testRequestGET() {
        waitUntil { done in
            let request = Request {
                $0.authentication = .client
                $0.path = "/api/users"
                $0.parameters = [
                    "per_page": 10
                ]
            }

            self.client.request(request).subscribe { event in
                switch event {
                case .success(let json):
                    XCTAssert(json["data"].arrayValue.count == 10)

                case .failure(let error):
                    XCTAssert(false, "\(error)")
                }
                done?()
            }.disposed(by: self.disposeBag)
        }
    }

    func testRequestGET404() {
        waitUntil { done in
            let request = Request {
                $0.path = "/some_strange_request"
            }

            self.client.request(request).subscribe { event in
                switch event {
                case .success:
                    XCTAssert(false, "Should not get here")

                case .failure(let error):
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
                        XCTAssert((underlyingError as! AFError).responseCode == 404)
                    } else {
                        XCTAssert(false, "Expect to have error 404, got \(apiError)")
                    }
                }
                done?()
            }.disposed(by: self.disposeBag)
        }
    }
}
