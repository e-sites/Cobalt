//
//  StubbingManager.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 02/11/2022.
//  Copyright © 2022 E-sites. All rights reserved.
//

import Foundation
import Combine

public class StubbingManager {
    private(set) var isEnabled = false
    private var stubs: [Stub] = []
    
    public func add(_ stub: Stub) {
        stubs.append(stub)
    }
    
    public func remove(_ stub: Stub) {
        stubs.removeAll { $0 == stub }
    }
    
    public func removeAll() {
        stubs.removeAll()
    }
    
    public func register() {
        isEnabled = true
    }
    
    public func unregister() {
        isEnabled = false
    }
    
    func stub(request: Request) -> AnyPublisher<CobaltResponse, Error>? {
        guard let stub = stubs.first(where: { willStub(stub: $0, request: request) }) else {
            return nil
        }        
        
        if let error = stub.error {
            return Fail<CobaltResponse, Error>(error: error)
                .delay(for: .milliseconds(Int(stub.delay * 100)), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        
        guard let cobaltResponse = stub.data.asCobaltResponse() else {
            return Fail<CobaltResponse, Error>(error: .empty)
                .delay(for: .milliseconds(Int(stub.delay * 100)), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        
        return Just(cobaltResponse)
            .setFailureType(to: Error.self)
            .delay(for: .milliseconds(Int(stub.delay * 100)), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func willStub(stub: Stub, request: Request) -> Bool {
        guard request.host == stub.host || stub.host == nil || request.host == nil,
              stub.httpMethod == request.httpMethod,
              request.path.range(of: stub.path, options: .regularExpression, range: nil, locale: nil) != nil else {
            return false
        }
        return true
    }
}
