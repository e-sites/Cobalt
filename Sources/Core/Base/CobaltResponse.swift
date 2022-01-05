//
//  CobaltResponse.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation

public protocol CobaltResponse {}

extension CobaltResponse {
    var flatJSONString: String? {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: []) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

extension Data {
    func asCobaltResponse() -> CobaltResponse? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: self, options: []) else {
            if let string = String(data: self, encoding: .utf8) {
                return string
            }
            return nil
        }
        
        if let cobaltValue = jsonObject as? CobaltResponse {
            return cobaltValue
            
        } else if let array = jsonObject as? [Any] {
            return array
                
        } else if let dictionary = jsonObject as? [String: Any] {
            return dictionary
            
        } else {
            return nil
        }
    }
}

public extension CobaltResponse {
    
    func map<T: Decodable>(to type: T.Type, with builder: ((JSONDecoder) -> Void)? = nil) throws -> T {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        builder?(jsonDecoder)
        let data = try JSONSerialization.data(withJSONObject: self, options: .fragmentsAllowed)
        return try jsonDecoder.decode(type, from: data)
    }
}

extension Array: CobaltResponse { }
extension Dictionary: CobaltResponse where Key == String { }
