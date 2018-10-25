//
//  String+JSON.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import SwiftyJSON

extension JSON {
    var flatString: String? {
        return self.rawString(.utf8, options: JSONSerialization.WritingOptions(rawValue: 0))
    }

    public func map<T: Decodable>(to type: T.Type, with builder: ((JSONDecoder) -> Void)? = nil) throws -> T {
        let jsonDecoder = JSONDecoder()
        builder?(jsonDecoder)
        let data = try self.rawData()
        return try jsonDecoder.decode(type, from: data)
    }
}

extension Dictionary {
    var flatJSONString: String? {
        let json = JSON(self)
        return json.flatString
    }
}
