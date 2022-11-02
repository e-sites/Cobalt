//
//  ClientService+Stubbing.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 02/11/2022.
//  Copyright © 2022 E-sites. All rights reserved.
//

import Foundation
import Cobalt

fileprivate var _swizzled = false
fileprivate var stubbingManagerKey: UInt8 = 0
fileprivate var stubbingPublisherKey: UInt8 = 0

extension ClientService {
    
    @objc
    func swizzleStubbing() {
        if _swizzled {
            return
        }
        _swizzled = true

        if let originalMethod = class_getInstanceMethod(object_getClass(self), #selector(shouldStub)),
            let swizzledMethod = class_getInstanceMethod(object_getClass(self), #selector(swizzledShouldStub)) {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    var stubbingManager: StubbingManager {
        guard let getAss = objc_getAssociatedObject(self, &stubbingManagerKey) as? StubbingManager else {
            let stubbingManager = StubbingManager()
            objc_setAssociatedObject(self, &stubbingManagerKey, stubbingManager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return stubbingManager
        }

        return getAss
    }

    @objc
    dynamic func swizzledShouldStub() -> Bool {
        guard let currentRequest, stubbingManager.isEnabled else {
            return swizzledShouldStub()
        }
        stubbedPublisher = stubbingManager.stub(request: currentRequest)
        return stubbedPublisher != nil
    }
}

