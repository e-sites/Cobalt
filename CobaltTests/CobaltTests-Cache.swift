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
@testable import CobaltCache

class CobaltTestsCache: CobaltTests {
    
    override func setUp() {
        super.setUp()
        client.cache.clearAll()
    }
    
    func testCache() {
        waitUntil { done in
            let request = CobaltRequest {
                $0.authentication = .client
                $0.path = "/api/users"
                $0.parameters = [
                    "per_page": 10
                ]
                $0.diskCachePolicy = .expires(seconds: 10)
            }
            
            self.client.request(request).sink(receiveCompletion: { event in
                switch event {
                case .finished:
                    break
                case .failure(let error):
                    XCTAssert(false, "\(error)")
                    done?()
                }
            }, receiveValue: { response in
                if let dictionary = response as? [String: Any], let data = dictionary["data"] as? [Any] {
                    expect(data.count) == 10
                } else {
                    XCTAssert(false, "Response \(response) is not a dictionary")
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                    let request = CobaltRequest {
                        $0.authentication = .client
                        $0.path = "/api/users"
                        $0.parameters = [
                            "per_page": 10
                        ]
                        $0.diskCachePolicy = .expires(seconds: 10)
                    }
                    
                    self.client.request(request).sink(receiveCompletion: { event in
                        switch event {
                        case .finished:
                            break
                        case .failure(let error):
                            XCTAssert(false, "\(error)")
                        }
                        done?()
                    }, receiveValue: { response in
                        if let dictionary = response as? [String: Any], let data = dictionary["data"] as? [Any] {
                            expect(data.count) == 10
                        } else {
                            XCTAssert(false, "Response \(response) is not a dictionary")
                        }
                    }).store(in: &self.cancellables)
                }
            }).store(in: &self.cancellables)
        }
    }
    
    func testNoCache() {
        waitUntil { done in
            let request = CobaltRequest {
                $0.authentication = .client
                $0.path = "/api/users"
                $0.parameters = [
                    "per_page": 10
                ]
                $0.diskCachePolicy = .expires(seconds: 10)
            }
            
            self.client.request(request).sink(receiveCompletion: { event in
                switch event {
                case .finished:
                    break
                case .failure(let error):
                    XCTAssert(false, "\(error)")
                    done?()
                }
            }, receiveValue: { response in
                if let dictionary = response as? [String: Any], let data = dictionary["data"] as? [Any] {
                    expect(data.count) == 10
                } else {
                    XCTAssert(false, "Response \(response) is not a dictionary")
                }
                
                let newRequest = CobaltRequest {
                    $0.authentication = .client
                    $0.path = "/api/users"
                    $0.parameters = [
                        "per_page": 5
                    ]
                    $0.diskCachePolicy = .expires(seconds: 10)
                }
                expect(newRequest.cacheKey) != request.cacheKey
                self.client.request(newRequest).sink(receiveCompletion: { event in
                    switch event {
                    case .finished:
                        break
                    case .failure(let error):
                        XCTAssert(false, "\(error)")
                    }
                    done?()
                }, receiveValue: { resonse2 in
                    if let dictionary = resonse2 as? [String: Any], let data = dictionary["data"] as? [Any] {
                        expect(data.count) == 5
                    } else {
                        XCTAssert(false, "Response \(resonse2) is not a dictionary")
                    }
                }).store(in: &self.cancellables)
                
            }).store(in: &self.cancellables)
        }
    }
}
