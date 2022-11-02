//
//  Stub.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 02/11/2022.
//  Copyright © 2022 E-sites. All rights reserved.
//

import Foundation
import Alamofire

public class Stub: Hashable {
    let uuid = UUID().uuidString
    
    public var path: String = "/"
    public var host: String?
    public var httpMethod: HTTPMethod = .get
    public var data: Data = Data()
    public var error: Error?
    public var delay: TimeInterval = 0.1
    
    public init() {

    }

    public init(_ builder: ((Stub) -> Void)) {
        builder(self)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
    
    public static func == (lhs: Stub, rhs: Stub) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
