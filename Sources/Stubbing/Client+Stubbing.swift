//
//  Client+Stubbing.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 02/11/2022.
//  Copyright © 2022 E-sites. All rights reserved.
//

import Foundation

extension Client {
    /// The StubbingManager
    public var stubbing: StubbingManager {
        return service.stubbingManager
    }
}
