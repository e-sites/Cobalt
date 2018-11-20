//
//  CobaltTests-Logging.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 05/09/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import XCTest
import Nimble
import Promises
import Alamofire
import Foundation
@testable import Cobalt

class CobaltTestsLogging: CobaltTests {
    func testMaskingRequests() {
        let dictionary: Parameters = [
            "some": "Aliquam tincidunt quis mi in blandit. Sed augue eros, consectetur sed facilisis eget, ultricies in ex. Suspendisse sagittis, velit a rutrum rhoncus, nulla dui pulvinar lectus, nec placerat ipsum lorem nec enim. Fusce vel neque quis risus lobortis efficitur. Nullam tempus diam vel nunc lacinia, bibendum tincidunt turpis laoreet. Nunc accumsan, dolor ut mollis blandit, magna sem vulputate lectus, eget vulputate elit ligula eget lorem. Ut a urna vulputate, mattis sapien at, ultrices quam. Cras in arcu orci. Proin at sagittis ex. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Sed gravida quam ut metus aliquet, ut aliquet tellus tempor. Donec fermentum ante mattis odio interdum, venenatis lacinia risus suscipit. Vestibulum in pellentesque leo.Donec sit amet consectetur risus, a fringilla magna. Fusce ac tellus tristique erat placerat tempor a a urna. Ut diam sapien, feugiat ac efficitur ut, volutpat ac sapien. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Mauris vehicula fermentum ipsum, vel finibus dui pellentesque ac. In at turpis quis lacus commodo cursus. Pellentesque sed sagittis mauris, eu malesuada nibh. Pellentesque eu interdum justo. Proin finibus, ligula in ultrices gravida, quam nibh imperdiet justo, non interdum quam orci vitae nulla. Sed hendrerit venenatis aliquet. Ut pharetra vitae risus id dictum. Suspendisse id lectus quis ante scelerisque posuere. Nulla vitae enim diam. Nunc venenatis sed arcu quis tincidunt.",
            "path": [
                "to": [
                    "token": "ABCDEF",
                    "username": "basvankuijck"
                ]
            ],
            "halfMasked_token": "123456",
            "password": "Test123"
        ]

        guard let logParams = client.dictionaryForLogging(dictionary, options: [
            "password": .masked,
            "some": .shortened,
            "path.to.token": .masked,
            "halfMasked_token": .halfMasked
            ]) else {
                XCTAssert(false, "'logParams' should not be nil")
            return
        }

        if let string = logParams["some"] as? String {
            XCTAssertEqual(string, "Aliquam tincidunt quis mi in blandit. Sed augue eros, consectetur sed facilisis eget, ultricies in ex. Suspendisse sagittis, vel...")
        } else {
            XCTAssert(false, "Expected 'some' in dictionary")
        }

        if let string = logParams["password"] as? String {
            XCTAssertEqual(string, "***")
        } else {
            XCTAssert(false, "Expected 'password' in dictionary")
        }

        if let string = logParams["halfMasked_token"] as? String {
            XCTAssertEqual(string, "123***")
        } else {
            XCTAssert(false, "Expected 'halfMasked_token' in dictionary")
        }

        if let dic1 = logParams["path"] as? [String: Any], let dic2 = dic1["to"] as? [String: String] {
            XCTAssertEqual(dic2["token"], "***")
            XCTAssertEqual(dic2["username"], "basvankuijck")
        } else {
            XCTAssert(false, "Expected 'path.to' in dictionary")
        }

    }
}
