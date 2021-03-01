//
//  CobaltTests-Authentication.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 12/07/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//


import XCTest
import Alamofire
import RxSwift
import RxCocoa
import Foundation
@testable import Cobalt

class CobaltTestsAuthentication: CobaltTests {
    override func setUp() {
        super.setUp()
        config.authentication.authorization = .basicHeader
        config.host = "https://apps.e-sites.nl"
        config.authentication.path = "/prototypes/cobalt/access_token.json"
    }
    
    func testsAuthenticate() {
        waitUntil { done in
            let request = Request {
                $0.authentication = .oauth2(.clientCredentials)
                $0.path = "/prototypes/cobalt/users.php"
            }

            self.client.request(request).subscribe { event in
                switch event {
                case .success(let json):
                    XCTAssert(json["users"].arrayValue.count == 2)
                case .failure(let error):
                    XCTAssert(false, "\(error)")
                }
                done?()
            }.disposed(by: self.disposeBag)
        }
    }

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
        XCTAssert(AccessToken.get(host: host1, grantType: .password) == nil)

        guard let getAccessToken1 = AccessToken.get(host: host1, grantType: .clientCredentials) else {
            XCTAssert(false, "Should have gotten accessToken1")
            return
        }

        guard let getAccessToken2 = AccessToken.get(host: host2, grantType: .password) else {
            XCTAssert(false, "Should have gotten accessToken2")
            return
        }

        XCTAssert(accessToken1.accessToken == getAccessToken1.accessToken)
        XCTAssert(getAccessToken1.refreshToken == nil)
        XCTAssert(accessToken1.refreshToken == nil)
        XCTAssert(accessToken1.grantType == getAccessToken1.grantType)
        XCTAssert(accessToken1.expireDate?.timeIntervalSince1970 == getAccessToken1.expireDate?.timeIntervalSince1970)

        XCTAssert(accessToken2.accessToken == getAccessToken2.accessToken)
        XCTAssert(accessToken2.refreshToken == getAccessToken2.refreshToken)
        XCTAssert(accessToken2.grantType == getAccessToken2.grantType)
        XCTAssert(accessToken2.expireDate?.timeIntervalSince1970 == getAccessToken2.expireDate?.timeIntervalSince1970)

        accessToken1.clear()
        XCTAssert(AccessToken.get(host: host1, grantType: .clientCredentials) == nil)

        accessToken2.clear()
        XCTAssert(AccessToken.get(host: host2, grantType: .password) == nil)
    }
}
