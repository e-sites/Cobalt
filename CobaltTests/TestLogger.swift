//
//  TestLogger.swift
//  CobaltTests
//
//  Created by Bas van Kuijck on 11/07/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
@testable import Cobalt

class TestLogger: Cobalt.Logger {
    func verbose(_ items: Any...) {
        print("[VER]", items.map { "\($0)" }.joined(separator: " "))
    }

    func warning(_ items: Any...) {
        print("[WAR]", items.map { "\($0)" }.joined(separator: " "))
    }

    func debug(_ items: Any...) {
        print("[DEB]", items.map { "\($0)" }.joined(separator: " "))
    }

    func success(_ items: Any...) {
        print("[SUC]", items.map { "\($0)" }.joined(separator: " "))
    }

    func error(_ items: Any...) {
        print("[ERR]", items.map { "\($0)" }.joined(separator: " "))
    }

    func log(_ items: Any...) {
        print("[LOG]", items.map { "\($0)" }.joined(separator: " "))
    }

    func info(_ items: Any...) {
        print("[INF]", items.map { "\($0)" }.joined(separator: " "))
    }

    func request(_ items: Any...) {
        if items.count < 3 {
            return
        }
        let stringItems = items.map { "\($0)" }
        print("[REQ]", stringItems.first!, stringItems[1], stringItems[2])
    }

    func response(_ items: Any...) {
        if items.count < 3 {
            return
        }
        let stringItems = items.map { "\($0)" }
        print("[RES]", stringItems.first!, stringItems[1], stringItems[2])
    }
}
