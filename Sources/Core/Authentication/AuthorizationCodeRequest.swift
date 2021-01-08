//
//  File.swift
//  
//
//  Created by Thomas Roovers on 07/01/2021.
//

import Foundation

public struct AuthorizationCodeRequest {
    public var url: URL
    public var redirectUri: String
    public var state: String?
    public var codeVerifier: String?
}
