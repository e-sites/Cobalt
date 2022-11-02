//
//  CobaltTests-Stubbing.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 02/11/2022.
//  Copyright © 2022 E-sites. All rights reserved.
//

import Foundation
import XCTest
import Nimble
import Alamofire
import Foundation
import Combine
@testable import Cobalt
@testable import CobaltStubbing

class CobaltTestsStubbing: CobaltTests {
    
    override func tearDown() {
        super.tearDown()
        client.stubbing.removeAll()
    }
    
    override func setUp() {
        super.setUp()
        client.stubbing.register()
    }
    
    func testStubbing() {
        let stubbedResponse = #"""
{"page":1,"per_page":6,"total":12,"total_pages":2,"data":[{"id":1,"email":"george.bluth@reqres.in","first_name":"George","last_name":"Bluth","avatar":"https://reqres.in/img/faces/1-image.jpg"},{"id":2,"email":"janet.weaver@reqres.in","first_name":"Janet","last_name":"Weaver","avatar":"https://reqres.in/img/faces/2-image.jpg"},{"id":3,"email":"emma.wong@reqres.in","first_name":"Emma","last_name":"Wong","avatar":"https://reqres.in/img/faces/3-image.jpg"},{"id":4,"email":"eve.holt@reqres.in","first_name":"Eve","last_name":"Holt","avatar":"https://reqres.in/img/faces/4-image.jpg"},{"id":5,"email":"charles.morris@reqres.in","first_name":"Charles","last_name":"Morris","avatar":"https://reqres.in/img/faces/5-image.jpg"},{"id":6,"email":"tracey.ramos@reqres.in","first_name":"Tracey","last_name":"Ramos","avatar":"https://reqres.in/img/faces/6-image.jpg"}],"support":{"url":"https://reqres.in/#support-heading","text":"To keep ReqRes free, contributions towards server costs are appreciated!"}}
"""#
        
        client.stubbing.add(Stub {
            $0.path = "/api/users"
            $0.data = stubbedResponse.data(using: .utf8)!
        })
        
        waitUntil { done in
            let request = CobaltRequest {
                $0.authentication = .client
                $0.path = "/api/users"
                $0.parameters = [
                    "per_page": 2
                ]
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
                    expect(data.count) == 6
                } else {
                    XCTAssert(false, "Response \(response) is not a dictionary")
                }
            }).store(in: &self.cancellables)
        }
    }
    
    func testStubbingRegex() {
        let stubbedResponse = #"""
{"data":{"id":2,"email":"janet.weaver@reqres.in","first_name":"Janet","last_name":"Weaver","avatar":"https://reqres.in/img/faces/2-image.jpg"},"support":{"url":"https://reqres.in/#support-heading","text":"To keep ReqRes free, contributions towards server costs are appreciated!"}}
"""#
        
        client.stubbing.add(Stub {
            $0.path = "/api/users/([0-9]+)"
            $0.data = stubbedResponse.data(using: .utf8)!
        })
        
        waitUntil { done in
            let request = CobaltRequest {
                $0.authentication = .client
                $0.path = "/api/users/5"
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
                if let dictionary = response as? [String: Any], let data = dictionary["data"] as? [String: Any] {
                    expect(data["email"] as? String) == "janet.weaver@reqres.in"
                } else {
                    XCTAssert(false, "Response \(response) is not a dictionary")
                }
            }).store(in: &self.cancellables)
        }
    }
    
    func testErrorStubbing() {
        client.stubbing.add(Stub {
            $0.path = "/api/users"
            $0.error = CobaltError.missingClientAuthentication
        })
        
        waitUntil { done in
            let request = CobaltRequest {
                $0.authentication = .client
                $0.path = "/api/users"
                $0.parameters = [
                    "per_page": 6
                ]
            }
            
            self.client.request(request).sink(receiveCompletion: { event in
                switch event {
                case .finished:
                    XCTAssert(false, "Should not reach this")
                case .failure(let error):
                    XCTAssertEqual(error.code, CobaltError.missingClientAuthentication.code)
                }
                done?()
            }, receiveValue: { _ in
                
            }).store(in: &self.cancellables)
        }
    }
}
