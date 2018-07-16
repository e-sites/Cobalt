//
//  AccessToken.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
#if !targetEnvironment(simulator)
import KeychainAccess
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
        case host
    }

    #if !targetEnvironment(simulator)
    private let keychain: Keychain
    #endif

    var accessToken: String?
    var refreshToken: String?
    var expireDate: Date?
    var grantType: OAuthenticationGrantType? {
        set {
            _grantType = AccessToken._transform(grantType: newValue)
        }
        get {
            return _grantType
        }
    }
    private var _grantType: OAuthenticationGrantType?
    var host: String = ""

    static private func _transform(grantType: OAuthenticationGrantType?) -> OAuthenticationGrantType? {
        if grantType == .refreshToken {
            return .password
        }
        return grantType
    }

    static func get(host: String, grantType: OAuthenticationGrantType) -> AccessToken? {
        let accessToken = AccessToken(host: host)
        let accessTokenLevel = accessToken.grantType?.level ?? 0
        if accessTokenLevel < grantType.level {
            return nil
        }
        if accessToken.accessToken == nil {
            return nil
        }
        return accessToken
    }

    init(host: String) {
        self.host = host
        #if targetEnvironment(simulator)
        accessToken = UserDefaults.standard.string(forKey: "\(host):\(Constant.accessTokenKey)")
        refreshToken = UserDefaults.standard.string(forKey: "\(host):\(Constant.refreshTokenKey)")
        if let rawValue = UserDefaults.standard.string(forKey: "\(host):\(Constant.grantTypeKey)") {
            self.grantType = OAuthenticationGrantType(rawValue: rawValue)
        }
        let timeInterval = UserDefaults.standard.double(forKey: "\(host):\(Constant.expireDateKey)")
        expireDate = Date(timeIntervalSince1970: timeInterval)

        #else
        self.keychain = Keychain(server: host, protocolType: host.contains("https://") ? .https : .http)
        accessToken = keychain[Constant.accessTokenKey]
        refreshToken = keychain[Constant.refreshTokenKey]
        if let timeString = keychain[Constant.expireDateKey], let timeInterval = TimeInterval(timeString) {
            expireDate = Date(timeIntervalSince1970: timeInterval)
        }
        if let grantType = keychain[Constant.grantTypeKey] {
            self.grantType = OAuthenticationGrantType(rawValue: grantType)
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
        UserDefaults.standard.set(accessToken, forKey: "\(host):\(Constant.accessTokenKey)")
        UserDefaults.standard.set(refreshToken, forKey: "\(host):\(Constant.refreshTokenKey)")
        UserDefaults.standard.set(grantType?.rawValue, forKey: "\(host):\(Constant.grantTypeKey)")
        UserDefaults.standard.set(expireDate?.timeIntervalSince1970, forKey: "\(host):\(Constant.expireDateKey)")
        _ = UserDefaults.standard.synchronize()
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
        return "<AccessToken> [ server: \(host), " +
            "accessToken: \(optionalDescription(accessToken)), " +
            "refreshToken: \(optionalDescription(refreshToken)), " +
        "grantType: \(optionalDescription(grantType)), expires in: \(expiresIn)s ]"
    }
}
