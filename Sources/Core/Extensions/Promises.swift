//
//  Promises+rx.swift
//  Alamofire
//
//  Created by Bas van Kuijck on 01/05/2018.
//

import Foundation
import Promises
import RxSwift

extension Promise {
    public func asSingle() -> Single<Value> {
        return Observable<Value>.create { observer in
            self.then { value in
                observer.onNext(value)
                observer.onCompleted()
            }.catch { error in
                observer.onError(error)
            }

            return Disposables.create { }
        }.asSingle()
    }
}

func firstly<T>(_ closure: (() throws -> Promise<T>)) -> Promise<T> {
    do {
        return try closure()
        
    } catch let error {
        return Promise(error)
    }
}
