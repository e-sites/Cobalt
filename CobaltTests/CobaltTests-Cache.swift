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
import Alamofire
import Foundation
import Combine
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
            
            self.client.request(request).sink(receiveCompletion: { event in
                switch event {
                case .finished:
                    break
                case .failure(let error):
                    XCTAssert(false, "\(error)")
                    done()
                }
            }, receiveValue: { json in
                expect(json["data"].arrayValue.count) == 10
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                    let request = Request {
                        $0.authentication = .client
                        $0.path = "/api/users"
                        $0.parameters = [
                            "per_page": 10
                        ]
                        $0.cachePolicy = .expires(seconds: 10)
                    }
                    
                    self.client.request(request).sink(receiveCompletion: { event in
                        switch event {
                        case .finished:
                            break
                        case .failure(let error):
                            XCTAssert(false, "\(error)")
                        }
                        done()
                    }, receiveValue: { json in
                        expect(json["data"].arrayValue.count) == 10
                    }).store(in: &self.cancellables)
                }
            }).store(in: &self.cancellables)
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
            
            self.client.request(request).sink(receiveCompletion: { event in
                switch event {
                case .finished:
                    break
                case .failure(let error):
                    XCTAssert(false, "\(error)")
                    done()
                }
            }, receiveValue: { json in
                expect(json["data"].arrayValue.count) == 10
                
                let request = Request {
                    $0.authentication = .client
                    $0.path = "/api/users"
                    $0.parameters = [
                        "per_page": 5
                    ]
                    $0.cachePolicy = .expires(seconds: 10)
                }
                
                self.client.request(request).sink(receiveCompletion: { event in
                    switch event {
                    case .finished:
                        break
                    case .failure(let error):
                        XCTAssert(false, "\(error)")
                    }
                    done()
                }, receiveValue: { json in
                    expect(json["data"].arrayValue.count) == 5
                }).store(in: &self.cancellables)
                
            }).store(in: &self.cancellables)
        }
    }
}
