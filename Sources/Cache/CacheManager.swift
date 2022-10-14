//
//  CacheManager.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 23/08/2019.
//  Copyright © 2019 E-sites. All rights reserved.
//

import Foundation

public enum CacheError: Swift.Error {
    case neverCached
    case expired
    case notFound
}

public class CacheManager {
    private enum Constants {
        static let cachedMappingKey = "cobalt_cachedMappingKey"
    }

    private var _cachedMapping: [String: Date] {
        get {
            return (UserDefaults.standard.dictionary(forKey: Constants.cachedMappingKey) as? [String: Date]) ?? [:]
        }
        set {
            if newValue.isEmpty {
                UserDefaults.standard.removeObject(forKey: Constants.cachedMappingKey)
                return
            }
            UserDefaults.standard.set(newValue, forKey: Constants.cachedMappingKey)
        }
    }

    private var _cacheFolder: URL {
        var url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        url.appendPathComponent("com.esites.suite.cobalt")
        url.appendPathComponent("cache")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }

    init() {
        clearExpired()
    }

    /// Clear all cached files (removes the cobalt cache directory)
    public func clearAll() {
        try? FileManager.default.removeItem(atPath: _cacheFolder.path)
        UserDefaults.standard.removeObject(forKey: Constants.cachedMappingKey)
    }

    /// Clears the expired cached files
    public func clearExpired() {
        let now = Date()
        for (urlString, date) in _cachedMapping where date < now {
            _cachedMapping.removeValue(forKey: urlString)

            guard let url = URL(string: urlString) else {
                continue
            }
            try? FileManager.default.removeItem(atPath: url.path)
//            print("Remove: \(url)")
        }
    }

    func getCachedResponse(for request: Request) -> CobaltResponse? {
        let url = _url(for: request)
        do {
            switch request.diskCachePolicy {
            case .never:
                throw CacheError.neverCached

            case .expires:
                if !FileManager.default.fileExists(atPath: url.path) {
                    return nil
                }

                // Check if the cache expired
                if let date = _cachedMapping[url.absoluteString], date < Date() {
                    throw CacheError.expired
                }
                
                let data = try Data(contentsOf: url)
                
                guard let response = try JSONSerialization.jsonObject(with: data, options: []) as? CobaltResponse else {
                    throw CacheError.notFound
                }
                return response
            }
        } catch {
            //                print("Error retrieving cache: \(error)")
            _clear(for: request)
        }
        return nil
    }

    func write(request: Request, response: CobaltResponse) {
        switch request.diskCachePolicy {
        case .never:
            return

        case .expires(let interval):
            do {
                let data = try JSONSerialization.data(withJSONObject: response, options: [])
                let url = _url(for: request)
                _cachedMapping[url.absoluteString] = Date(timeIntervalSinceNow: interval)
                //                print("Write cache to: \(url)")
                try data.write(to: url)
            } catch {
                //                print("Error writing cache: \(error)")
            }
        }
    }

    private func _clear(for request: Request) {
        let url = _url(for: request)
        //        print("Clear cache: \(url)")
        _cachedMapping.removeValue(forKey: url.absoluteString)

        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(atPath: url.path)
        }
    }

    private func _url(for request: Request) -> URL {
        var url = _cacheFolder
        let cacheKey = request.cacheKey
        url.appendPathComponent(cacheKey + ".cache")
        return url
    }
}
