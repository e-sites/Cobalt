//
//  CacheManager.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation
import SwiftyJSON

public class CacheManager {

    private var _cacheFolder: URL {
        var url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        url.appendPathComponent("com.esites.suite.cobalt")
        url.appendPathComponent("cache")
        return url
    }

    /// Clear all cached files (removes the cobalt cache directory)
    public func clear() {
        try? FileManager.default.removeItem(atPath: _cacheFolder.path)
    }

    func getCachedJSON(for request: Request) -> JSON? {
        switch request.cachePolicy {
        case .never:
            return nil

        case .expires(let interval):
            let url = _url(for: request)
            if !FileManager.default.fileExists(atPath: url.path) {
                return nil
            }

            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

                // Check if the cache expired
                if let date = attributes[FileAttributeKey.creationDate] as? Date,
                    Date(timeIntervalSinceNow: -interval) > date {
                    throw SwiftyJSONError.notExist
                }
                let jsonString = try String(contentsOfFile: url.path)
                let json = JSON(parseJSON: jsonString)
                if json == .null {
                    throw SwiftyJSONError.notExist
                }
                return json
            } catch {
//                print("Error retrieving cache: \(error)")
                _clear(for: request)
                return nil
            }
        }
    }

    func write(request: Request, response: JSON) {
        switch request.cachePolicy {
        case .never:
            return

        default:
            break
        }

        do {
            let data = try response.rawData()
            let url = _url(for: request)
//            print("Write cache to: \(url)")
            try data.write(to: url)
        } catch {
//            print("Error writing cache: \(error)")
        }
    }

    private func _clear(for request: Request) {
        let url = _url(for: request)
//        print("Clear cache: \(url)")
        try? FileManager.default.removeItem(atPath: url.path)
    }

    private func _url(for request: Request) -> URL {
        var url = _cacheFolder
        let cacheKey = request.cacheKey
        if cacheKey.count > 2 {
            let endIndex = cacheKey.index(cacheKey.startIndex, offsetBy: 1)
            url.appendPathComponent(String(cacheKey[cacheKey.startIndex...endIndex]))
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        url.appendPathComponent(cacheKey + ".cache")
        return url
    }
}
