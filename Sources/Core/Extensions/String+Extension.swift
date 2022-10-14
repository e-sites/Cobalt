//
//  String+Extension.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation
import CryptoKit

extension String {
    var md5: String {
        let digest = Insecure.MD5.hash(data: data(using: .utf8) ?? Data())
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
    
    var urlEncoded: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? self
    }
    
    /// Combine the host and path
    /// - Parameters:
    ///   - host: `String`
    ///   - path: `String`
    /// - Returns: `String`
    static func combined(host: String, path: String) -> String {
        var newHost = host
        var newPath = path
        
        if host.hasSuffix("/") {
            newHost = String(host.dropLast())
        }
        if path.hasPrefix("/") {
            newPath = String(path.dropFirst())
        }
        return newHost + "/" + newPath
    }
}
