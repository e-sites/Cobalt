//
//  CobaltTests-Parsing.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 05/01/2022.
//  Copyright © 2022 E-sites. All rights reserved.
//

import XCTest
import Nimble
import Alamofire
import Foundation
import Combine
@testable import Cobalt

struct SomeObject: Codable, Identifiable {
    let id: Int
    let name: String
}

class CobaltTestsParsing: CobaltTests {
    lazy var testObjects = [ [ "id": 1, "name": "Bas" ], [ "id": 2, "name": "Thomas" ], [ "id": 3, "name": "Tirza" ], [ "id": 4, "name": "Tijs" ] ]
    
    func testCorrectParsingArray() {
        let array = testObjects
        
        do {
            let objects = try array.map(to: [SomeObject].self)
            expect(objects.count) == 4
        } catch {
            XCTAssert(false, "\(error)")
        }
    }
    
    func testIncorrectParsing() {
        let array = testObjects
        
        do {
            _ = try array.map(key: "objects", to: [SomeObject].self)
            XCTAssert(false, "Should not parse")
        } catch {
            if let error = error as? Cobalt.Error {
                XCTAssertEqual(error.code, 801)
            } else {
                XCTAssert(false, "\(error) is not Cobalt.Error")
            }
        }
    }
    
    func testCorrectParsingArrayWithKey() {
        let dictionary = [ "objects": testObjects ]
        
        do {
            let objects = try dictionary.map(key: "objects", to: [SomeObject].self)
            expect(objects.count) == 4
        } catch {
            XCTAssert(false, "\(error)")
        }
    }
    
    func testCorrectParsingDictionaryWithKey() {
        let dictionary = [ "object": [ "id": 1, "name": "Bas" ] ]
        
        do {
            let object = try dictionary.map(key: "object", to: SomeObject.self)
            expect(object.id) == 1
            expect(object.name) == "Bas"
        } catch {
            XCTAssert(false, "\(error)")
        }
    }
    
    func testStringCobaltResponse() {
        let data = "test-string".data(using: .utf8)!
        
        let cobaltResponse = data.asCobaltResponse()
        if let string = cobaltResponse as? String {
            XCTAssertEqual(string, "test-string")
        } else {
            XCTAssert(false, "\(String(describing: cobaltResponse)) is not a 'String'")
        }
    }
}
