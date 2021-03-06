//
//  String+Extension.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation
import CommonCrypto

extension String {
    var md5: String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)

        if let stringData = data(using: .utf8) {
            _ = stringData.withUnsafeBytes { body -> String in
                CC_MD5(body.baseAddress, CC_LONG(stringData.count), &digest)
                return ""
            }
        }

        return (0 ..< length).reduce("") {
            $0 + String(format: "%02x", digest[$1])
        }
    }
}
