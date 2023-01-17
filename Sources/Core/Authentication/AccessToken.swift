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
        fileprivate static let idTokenKey = "AccessToken._idToken"
        fileprivate static let refreshTokenKey = "AccessToken._refreshToken"
        fileprivate static let expireDateKey = "AccessToken._expireDate"
        fileprivate static let grantTypeKey = "AccessToken._grantType"
        fileprivate static let stored = "AccessToken._stored"
    }
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case idToken = "id_token"
        case host
    }

    #if !targetEnvironment(simulator)
    private var keychain: Keychain!
    #endif

    public internal(set) var accessToken: String?
    public internal(set) var idToken: String?
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
    
    init(grantType: OAuthenticationGrantType, accessToken: String, refreshToken: String, expireDate: Date, host: String) {
        self.grantType = grantType
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expireDate = expireDate
        self.host = host
        
        _setKeychain()
    }

    init(host: String) {
        self.host = host
        _setKeychain()
        if !UserDefaults.standard.bool(forKey: "\(host):\(Constant.stored)") {
            return
        }

        #if targetEnvironment(simulator)
        accessToken = UserDefaults.standard.string(forKey: "\(host):\(Constant.accessTokenKey)")
        idToken = UserDefaults.standard.string(forKey: "\(host):\(Constant.idTokenKey)")
        refreshToken = UserDefaults.standard.string(forKey: "\(host):\(Constant.refreshTokenKey)")
        if let rawValue = UserDefaults.standard.string(forKey: "\(host):\(Constant.grantTypeKey)") {
            self.grantType = OAuthenticationGrantType(rawValue: rawValue)
        }
        let timeInterval = UserDefaults.standard.double(forKey: "\(host):\(Constant.expireDateKey)")
        expireDate = Date(timeIntervalSince1970: timeInterval)

        #else
        idToken = keychain[Constant.idTokenKey]
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
        idToken = try container.decodeIfPresent(String.self, forKey: .idToken)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)

        let expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        expireDate = Date(timeIntervalSinceNow: TimeInterval(expiresIn))
    }

    public func store(host aHost: String? = nil) {
        if host.isEmpty, let aHost {
            host = aHost
        }
        if accessToken == nil {
            UserDefaults.standard.removeObject(forKey: "\(host):\(Constant.stored)")
        } else {
            UserDefaults.standard.set(true, forKey: "\(host):\(Constant.stored)")
        }

        #if targetEnvironment(simulator)
        UserDefaults.standard.set(accessToken, forKey: "\(host):\(Constant.accessTokenKey)")
        UserDefaults.standard.set(idToken, forKey: "\(host):\(Constant.idTokenKey)")
        UserDefaults.standard.set(refreshToken, forKey: "\(host):\(Constant.refreshTokenKey)")
        UserDefaults.standard.set(grantType?.rawValue, forKey: "\(host):\(Constant.grantTypeKey)")
        UserDefaults.standard.set(expireDate?.timeIntervalSince1970, forKey: "\(host):\(Constant.expireDateKey)")
        #else
        keychain[Constant.accessTokenKey] = accessToken
        keychain[Constant.refreshTokenKey] = refreshToken
        keychain[Constant.idTokenKey] = idToken
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
        idToken = nil
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
            "idToken: \(optionalDescription(Helpers.mask(string: idToken, type: .halfMasked))), " +
            "accessToken: \(optionalDescription(Helpers.mask(string: accessToken, type: .halfMasked))), " +
            "refreshToken: \(optionalDescription(Helpers.mask(string: refreshToken, type: .halfMasked))), " +
        "grantType: \(optionalDescription(grantType)), expires in: \(expiresIn)s ]"
    }
}
