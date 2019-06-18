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

public class AccessToken: Decodable, CustomStringConvertible {
    fileprivate struct Constant {
        fileprivate static let accessTokenKey = "AccessToken._accessToken"
        fileprivate static let refreshTokenKey = "AccessToken._refreshToken"
        fileprivate static let expireDateKey = "AccessToken._expireDate"
        fileprivate static let grantTypeKey = "AccessToken._grantType"
        fileprivate static let stored = "AccessToken._stored"
    }
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case host
    }

    #if !targetEnvironment(simulator)
    private var keychain: Keychain!
    #endif

    public internal(set) var accessToken: String?
    public internal(set) var refreshToken: String?
    public internal(set) var expireDate: Date?
    public internal(set) var grantType: OAuthenticationGrantType? {
        set {
            _grantType = AccessToken._transform(grantType: newValue)
        }
        get {
            return _grantType
        }
    }
    private var _grantType: OAuthenticationGrantType?

    var host: String = "" {
        didSet {
            _setKeychain()
        }
    }

    private func _setKeychain() {
        #if !targetEnvironment(simulator)
        keychain = Keychain(server: host, protocolType: host.contains("https://") ? .https : .http)
        #endif
    }

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
    
    init(grantType: OAuthenticationGrantType, accessToken: String, refreshToken: String, expireDate: Date, host: String? = nil) {
        self.grantType = grantType
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expireDate = expireDate
        self.host = host ?? ""
    }

    init(host: String) {
        self.host = host
        _setKeychain()
        if !UserDefaults.standard.bool(forKey: "\(host):\(Constant.stored)") {
            return
        }

        #if targetEnvironment(simulator)
        accessToken = UserDefaults.standard.string(forKey: "\(host):\(Constant.accessTokenKey)")
        refreshToken = UserDefaults.standard.string(forKey: "\(host):\(Constant.refreshTokenKey)")
        if let rawValue = UserDefaults.standard.string(forKey: "\(host):\(Constant.grantTypeKey)") {
            self.grantType = OAuthenticationGrantType(rawValue: rawValue)
        }
        let timeInterval = UserDefaults.standard.double(forKey: "\(host):\(Constant.expireDateKey)")
        expireDate = Date(timeIntervalSince1970: timeInterval)

        #else
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

    public var isExpired: Bool {
        guard let expireDate = self.expireDate else {
            return true
        }
        return expireDate < Date()
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)

        let expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        expireDate = Date(timeIntervalSinceNow: TimeInterval(expiresIn))
    }

    func store() {
        if accessToken == nil {
            UserDefaults.standard.removeObject(forKey: "\(host):\(Constant.stored)")
        } else {
            UserDefaults.standard.set(true, forKey: "\(host):\(Constant.stored)")
        }

        #if targetEnvironment(simulator)
        UserDefaults.standard.set(accessToken, forKey: "\(host):\(Constant.accessTokenKey)")
        UserDefaults.standard.set(refreshToken, forKey: "\(host):\(Constant.refreshTokenKey)")
        UserDefaults.standard.set(grantType?.rawValue, forKey: "\(host):\(Constant.grantTypeKey)")
        UserDefaults.standard.set(expireDate?.timeIntervalSince1970, forKey: "\(host):\(Constant.expireDateKey)")
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
        _ = UserDefaults.standard.synchronize()
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

    public var description: String {
        var expiresIn = 0
        if let expireDate = expireDate {
            expiresIn = Int(expireDate.timeIntervalSinceNow)
        }
        return "<AccessToken> [ server: \(host), " +
            "accessToken: \(optionalDescription(Client.mask(string: accessToken, type: .halfMasked))), " +
            "refreshToken: \(optionalDescription(Client.mask(string: refreshToken, type: .halfMasked))), " +
        "grantType: \(optionalDescription(grantType)), expires in: \(expiresIn)s ]"
    }
}
