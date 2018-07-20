//
//  Logger.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 11/07/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation

public protocol Logger {
    func verbose(_ items: Any...)
    func warning(_ items: Any...)
    func debug(_ items: Any...)
    func success(_ items: Any...)
    func error(_ items: Any...)
    func request(_ items: Any...)
    func response(_ items: Any...)
    func log(_ items: Any...)
}
