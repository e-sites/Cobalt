//
//  AccessToken.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import KeychainAccess

#if targetEnvironment(simulator)

import SwiftyUserDefaults
extension DefaultsKeys {
    fileprivate static let accessToken = DefaultsKey<String?>(AccessToken.Constant.accessTokenKey)
    fileprivate static let refreshToken = DefaultsKey<String?>(AccessToken.Constant.refreshTokenKey)
    fileprivate static let expireDate = DefaultsKey<Date?>(AccessToken.Constant.expireDateKey)
    fileprivate static let grantType = DefaultsKey<String?>(AccessToken.Constant.grantTypeKey)
}
#endif

class AccessToken: Decodable, CustomStringConvertible {
    fileprivate struct Constant {
        fileprivate static let accessTokenKey = "AccessToken._accessToken"
        fileprivate static let refreshTokenKey = "AccessToken._refreshToken"
        fileprivate static let expireDateKey = "AccessToken._expireDate"
        fileprivate static let grantTypeKey = "AccessToken._grantType"
    }
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }

    private let keychain = Keychain(service: "com.esites.Cobalt-accesstoken")

    var accessToken: String?
    var refreshToken: String?
    var expireDate: Date?
    var grantType: APIOAuthenticationGrantType? {
        set {
            _grantType = AccessToken._transform(grantType: newValue)
        }
        get {
            return _grantType
        }
    }
    private var _grantType: APIOAuthenticationGrantType?

    static private func _transform(grantType: APIOAuthenticationGrantType?) -> APIOAuthenticationGrantType? {
        if grantType == .refreshToken {
            return .password
        }
        return grantType
    }

    static func get(grantType: APIOAuthenticationGrantType) -> AccessToken? {
        let accessToken = AccessToken()
        let accessTokenLevel = accessToken.grantType?.level ?? 0
        if accessTokenLevel < grantType.level {
            return nil
        }
        if accessToken.accessToken == nil {
            return nil
        }
        return accessToken
    }

    init() {
        #if targetEnvironment(simulator)
        accessToken = Defaults[.accessToken]
        refreshToken = Defaults[.refreshToken]
        expireDate = Defaults[.expireDate]
        if let grantType = Defaults[.grantType] {
            self.grantType = APIOAuthenticationGrantType(rawValue: grantType)
        }
        #else
        accessToken = keychain[Constant.accessTokenKey]
        refreshToken = keychain[Constant.refreshTokenKey]
        if let timeString = keychain[Constant.expireDateKey], let timeInterval = TimeInterval(timeString) {
            expireDate = Date(timeIntervalSince1970: timeInterval)
        }
        if let grantType = keychain[Constant.grantTypeKey] {
            self.grantType = APIOAuthenticationGrantType(rawValue: grantType)
        }
        #endif
    }

    var isExpired: Bool {
        guard let expireDate = self.expireDate else {
            return true
        }
        return expireDate < Date()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)

        let expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        expireDate = Date(timeIntervalSinceNow: TimeInterval(expiresIn))
    }

    func store() {
        #if targetEnvironment(simulator)
        Defaults[.accessToken] = accessToken
        Defaults[.refreshToken] = refreshToken
        Defaults[.expireDate] = expireDate
        Defaults[.grantType] = grantType?.rawValue
        #else
        keychain[Constant.accessTokenKey] = accessToken
        keychain[Constant.refreshTokenKey] = refreshToken
        if let expireDateInterval = expireDate?.timeIntervalSince1970 {
            keychain[Constant.expireDateKey] = "\(Int(expireDateInterval))"
        } else {
            keychain[Constant.expireDateKey] = nil
        }
        keychain[Constant.grantTypeKey] = grantType?.rawValue

        #endif
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
        expireDate = nil
        grantType = nil
        store()
    }

    func invalidate() {
        expireDate = Date(timeIntervalSince1970: 0)
        store()
    }

    var description: String {
        var expiresIn = 0
        if let expireDate = expireDate {
            expiresIn = Int(expireDate.timeIntervalSinceNow)
        }
        return "<AccessToken> [ accessToken: \(optionalDescription(accessToken)), " +
            "refreshToken: \(optionalDescription(refreshToken)), " +
        "grantType: \(optionalDescription(grantType)), expires in: \(expiresIn)s ]"
    }
}
