//
//  RequestQueue.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 02/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import Alamofire
import SwiftyJSON

private class SingleMap {
    var single: Single<JSON>!
    var observer: ((SingleEvent<JSON>) -> Void)!

    func destroy() {
        single = nil
        observer = nil
    }
}

class RequestQueue {
    private weak var apiClient: Client!
    private(set) var requests: [Request] = []
    private var _singleMap: [Request: SingleMap] = [:]

    var count: Int {
        return requests.count
    }

    init(client: Client) {
        self.apiClient = client
    }

    func add(_ request: Request) {
        if requests.contains(request) {
            return
        }

        let map = SingleMap()
        map.single = Single<JSON>.create { [weak self, map] observer in
            map.observer = observer
            return Disposables.create {
                map.destroy()
                self?._singleMap.removeValue(forKey: request)
            }
        }
        _singleMap[request] = map
        requests.append(request)
        apiClient.logger?.verbose("Added to queue [\(count)]: \(request)")
    }

    func removeFirst() {
        if requests.isEmpty {
            return
        }
        let request = requests.removeFirst()
        _singleMap.removeValue(forKey: request)
    }

    func next() {
        if let nextRequest = requests.first {
            handle(request: nextRequest)
        }
    }

    func clear() {
        _singleMap.removeAll()
        requests.removeAll()
    }

    func single(of request: Request) -> Single<JSON>? {
        return _singleMap[request]?.single
    }

    func handle(request: Request) {
        let map = _singleMap[request]
        removeFirst()
        if map == nil {
            return
        }
        
        apiClient.request(request) { result in
            switch result {
            case .success(let json):
                map?.observer(.success(json))
            case .failure(let error):
                map?.observer(.error(error))
            }
        }
    }
}
