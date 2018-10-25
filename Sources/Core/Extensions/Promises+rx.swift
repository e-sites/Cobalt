//
//  Promises+rx.swift
//  Alamofire
//
//  Created by Bas van Kuijck on 01/05/2018.
//

import Foundation
import Promises
import RxSwift
import RxCocoa

extension Promise {
    public func asObservable() -> Observable<Value> {
        return Observable<Value>.create { observer in
            self.then { value in
                observer.onNext(value)
            }.catch { error in
                observer.onError(error)
            }

            return Disposables.create { }
        }
    }
}

func firstly<T>(_ closure: (() throws -> Promise<T>)) -> Promise<T> {
    do {
        return try closure()
        
    } catch let error {
        return Promise(error)
    }
}
