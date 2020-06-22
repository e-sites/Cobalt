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

class RequestQueue {
    private weak var apiClient: Client!
    private(set) var requests: [Request] = []
    private var _map: [Request: PublishRelay<Swift.Result<JSON, Swift.Error>>] = [:]

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
        _map[request] = PublishRelay<Swift.Result<JSON, Swift.Error>>()
        requests.append(request)
        apiClient.logger?.verbose("Added to queue [\(count)]: \(request)")
    }

    func removeFirst() {
        if requests.isEmpty {
            return
        }
        let request = requests.removeFirst()
        _map.removeValue(forKey: request)
    }

    func next() {
        if let nextRequest = requests.first {
            handle(request: nextRequest)
        }
    }

    func clear() {
        _map.removeAll()
        requests.removeAll()
    }

    func single(of request: Request) -> Single<JSON>? {
        return _map[request]?.map { result throws -> JSON in
            switch result {
            case .success(let json):
                return json
            case .failure(let error):
                throw error
            }
        }.take(1).asSingle()
    }

    func handle(request: Request) {
        let relay = _map[request]
        removeFirst()
        if relay == nil {
            return
        }
        
        apiClient.request(request) { result in
            switch result {
            case .success(let json):
                relay?.accept(.success(json))
            case .failure(let error):
                relay?.accept(.failure(error))
            }
        }
    }
}
