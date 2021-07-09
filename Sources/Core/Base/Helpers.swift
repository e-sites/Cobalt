//
//  Helpers.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 18/09/2020.
//  Copyright © 2020 E-sites. All rights reserved.
//

import Foundation

class Helpers {
    static func dictionaryForLogging(_ parameters: [String: Any]?,
                              options: [String: KeyLoggingOption]?) -> [String: Any]? {
        guard let theParameters = parameters, let theOptions = options else {
            return parameters
        }
        return _mask(parameters: theParameters, options: theOptions)
    }

    fileprivate static func _mask(parameters: [String: Any],
                           options: [String: KeyLoggingOption],
                           path: String = "") -> [String: Any] {
        var logParameters: [String: Any] = [:]
        for (key, value) in parameters {
            let type = options["\(path)\(key)"] ?? .default
            if let dictionary = value as? [String: Any], case KeyLoggingOption.default = type {
                logParameters[key] = _mask(parameters: dictionary, options: options, path: "\(path)\(key).")
                continue
            }
            guard let string = mask(string: value, type: type) else {
                continue
            }
            logParameters[key] = string
        }
        return logParameters
    }

    class func mask(string value: Any?, type: KeyLoggingOption) -> Any? {
        guard let value = value else {
            return nil
        }
        switch type {
        case .halfMasked:
            guard let stringValue = value as? String, !stringValue.isEmpty else {
                return value
            }
            let length = Int(floor(Double(stringValue.count) / 2.0))
            let startIndex = stringValue.startIndex
            let midIndex = stringValue.index(startIndex, offsetBy: length)
            return String(describing: stringValue[startIndex..<midIndex]) + "***"

        case .ignore:
            return nil

        case .replaced(let string):
            return string

        case .masked:
            return "***"

        case .shortened:
            let stringValue: String
            if let tmpValue = value as? String {
                stringValue = tmpValue
            } else if let tmpValue = value as? CobaltResponse, let jsonString = tmpValue.flatJSONString {
                stringValue = jsonString
            } else {
                stringValue = String(describing: value)
            }
            if stringValue.count > 128 {
                let startIndex = stringValue.startIndex
                let endIndex = stringValue.index(startIndex, offsetBy: 128)
                return String(describing: stringValue[startIndex..<endIndex]) + "..."
            } else {
                return value
            }
            
        default:
            return value
        }
    }
}
