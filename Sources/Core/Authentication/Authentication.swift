//
//  Authentication.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation

public enum Authentication {
    case none
    case client
    case oauth2(OAuthenticationGrantType)
}

public enum OAuthenticationGrantType: String {
    case clientCredentials = "client_credentials"
    case password
    case authorizationCode = "authorization_code"
    case refreshToken = "refresh_token"
    
    var refreshUsingRefreshToken: Bool {
        switch self {
        case .authorizationCode, .password:
            return true
        default:
            return false
        }
    }

    var level: Int {
        switch self {
        case .clientCredentials: return 1
        case .password, .refreshToken, .authorizationCode: return 2
        }
    }
}
