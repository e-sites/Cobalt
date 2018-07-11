//
//  APIAuthentication.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 01/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation

public enum APIAuthentication {
    case none
    case client
    case oauth2(APIOAuthenticationGrantType)
}

public enum APIOAuthenticationGrantType: String {
    case clientCredentials = "client_credentials"
    case password
    case refreshToken = "refresh_token"

    var level: Int {
        switch self {
        case .clientCredentials: return 1
        case .password, .refreshToken: return 2
        }
    }
}
