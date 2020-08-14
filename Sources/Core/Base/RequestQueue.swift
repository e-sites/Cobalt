//
//  RequestQueue.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 02/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Combine
import SwiftyJSON

class RequestQueue {
    private weak var apiClient: Client!
    private(set) var requests: [Request] = []
    private var _map: [Request: PassthroughSubject<JSON, Error>] = [:]

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
        _map[request] = PassthroughSubject<JSON, Error>()
        requests.append(request)
        apiClient.logger?.notice("Added to queue [\(count)]: \(request)")
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

    func publisher(of request: Request) -> AnyPublisher<JSON, Error>? {
        return _map[request]?.eraseToAnyPublisher()
    }

    func handle(request: Request) {
        let subject = _map[request]
        removeFirst()
        if subject == nil {
            return
        }
        
        apiClient.request(request).sink(receiveCompletion: { event in
            switch event {
            case .finished:
                subject?.send(completion: .finished)
                
            case .failure(let error):
                subject?.send(completion: .failure(error))
            }
        }, receiveValue: { json in
            subject?.send(json)
        }).store(in: &apiClient.cancellables)
    }
}
