//
//  StubbingManager.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 02/11/2022.
//  Copyright © 2022 E-sites. All rights reserved.
//

import Foundation
import Combine
import Cobalt

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
    
    public init() {
        
    }
    
    public func stub(request: CobaltRequest) -> AnyPublisher<CobaltResponse, CobaltError>? {
        guard let stub = stubs.first(where: { willStub(stub: $0, request: request) }) else {
            return nil
        }

        if let error = stub.error {
            return Fail<CobaltResponse, CobaltError>(error: (error as? CobaltError) ?? .underlying(error))
                .delay(for: .milliseconds(Int(stub.delay * 100)), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }

        guard let cobaltResponse = stub.data.asCobaltResponse() else {
            return Fail<CobaltResponse, CobaltError>(error: .empty)
                .delay(for: .milliseconds(Int(stub.delay * 100)), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }

        return Just(cobaltResponse)
            .setFailureType(to: CobaltError.self)
            .delay(for: .milliseconds(Int(stub.delay * 100)), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func willStub(stub: Stub, request: CobaltRequest) -> Bool {
        guard request.host == stub.host || stub.host == nil || request.host == nil,
              stub.httpMethod == request.httpMethod,
              request.path.range(of: stub.path, options: .regularExpression, range: nil, locale: nil) != nil else {
            return false
        }
        return true
    }
}
