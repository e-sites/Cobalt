//
//  String+Extension.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation

extension String {
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
