//
//  CobaltTests-Cache.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//


import Foundation
import XCTest
import RxSwift
import RxCocoa
import Alamofire
import Foundation
@testable import Cobalt

class CobaltTestsCache: CobaltTests {

    override func setUp() {
        super.setUp()
        client.cache.clearAll()
    }

    func testCache() {
        waitUntil { done in
            let request = Request {
                $0.authentication = .client
                $0.path = "/api/users"
                $0.parameters = [
                    "per_page": 10
                ]
                $0.cachePolicy = .expires(seconds: 10)
            }

            self.client.request(request).subscribe { event in
                switch event {
                case .success(let json):
                    XCTAssert(json["data"].arrayValue.count == 10)

                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                        let request = Request {
                            $0.authentication = .client
                            $0.path = "/api/users"
                            $0.parameters = [
                                "per_page": 10
                            ]
                            $0.cachePolicy = .expires(seconds: 10)
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

                case .failure(let error):
                    XCTAssert(false, "\(error)")
                }
            }.disposed(by: self.disposeBag)
        }
    }

    func testNoCache() {
        waitUntil { done in
            let request = Request {
                $0.authentication = .client
                $0.path = "/api/users"
                $0.parameters = [
                    "per_page": 10
                ]
                $0.cachePolicy = .expires(seconds: 10)
            }

            self.client.request(request).subscribe { event in
                switch event {
                case .success(let json):XCTAssert(json["data"].arrayValue.count == 10)
                    let request = Request {
                        $0.authentication = .client
                        $0.path = "/api/users"
                        $0.parameters = [
                            "per_page": 5
                        ]
                        $0.cachePolicy = .expires(seconds: 10)
                    }

                    self.client.request(request).subscribe { event in
                        switch event {
                        case .success(let json):XCTAssert(json["data"].arrayValue.count == 5)
                        case .failure(let error):
                            XCTAssert(false, "\(error)")
                        }
                        done?()
                    }.disposed(by: self.disposeBag)
                    
                case .failure(let error):
                    XCTAssert(false, "\(error)")
                }
            }.disposed(by: self.disposeBag)
        }
    }
}
