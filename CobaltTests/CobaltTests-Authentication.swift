//
//  CobaltTests-Authentication.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 12/07/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//


import XCTest
import Nimble
import Promises
import Alamofire
import Foundation
@testable import Cobalt

class CobaltTestsAuthentication: CobaltTests {

    func testDoubleAccessTokens() {
        let host1 = "https://www.e-sites.nl"
        let host2 = "https://www.github.com"

        let accessToken1 = AccessToken(host: host1)
        accessToken1.accessToken = "access_token1"
        accessToken1.expireDate = Date(timeIntervalSinceNow: 10)
        accessToken1.grantType = .clientCredentials
        accessToken1.store()

        let accessToken2 = AccessToken(host: host2)
        accessToken2.accessToken = "access_token2"
        accessToken2.refreshToken = "refres_token2"
        accessToken2.expireDate = Date(timeIntervalSinceNow: 20)
        accessToken2.grantType = .password
        accessToken2.store()

        expect(AccessToken.get(host: host1, grantType: .password)).to(beNil())

        guard let getAccessToken1 = AccessToken.get(host: host1, grantType: .clientCredentials) else {
            XCTAssert(false, "Should have gotten accessToken1")
            return
        }

        guard let getAccessToken2 = AccessToken.get(host: host2, grantType: .password) else {
            XCTAssert(false, "Should have gotten accessToken2")
            return
        }

        expect(accessToken1.accessToken) == getAccessToken1.accessToken
        expect(getAccessToken1.refreshToken).to(beNil())
            expect(accessToken1.refreshToken).to(beNil())
        expect(accessToken1.grantType) == getAccessToken1.grantType
        expect(accessToken1.expireDate?.timeIntervalSince1970) == getAccessToken1.expireDate?.timeIntervalSince1970

        expect(accessToken2.accessToken) == getAccessToken2.accessToken
        expect(accessToken2.refreshToken) == getAccessToken2.refreshToken
        expect(accessToken2.grantType) == getAccessToken2.grantType
        expect(accessToken2.expireDate?.timeIntervalSince1970) == getAccessToken2.expireDate?.timeIntervalSince1970

        accessToken1.clear()
        expect(AccessToken.get(host: host1, grantType: .clientCredentials)).to(beNil())

        accessToken2.clear()
        expect(AccessToken.get(host: host2, grantType: .password)).to(beNil())
    }
}
