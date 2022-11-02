//
//  Client+Stubbing.swift
//  Cobalt
//  
//
//  Created by Bas van Kuijck on 02/11/2022.
//  Copyright © 2022 E-sites. All rights reserved.
//

import Foundation
import Cobalt

extension CobaltClient {
    public var stubbing: StubbingManager {
        return service.stubbingManager
    }
}
