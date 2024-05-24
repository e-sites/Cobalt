//
//  RequestQueue.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 02/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Combine

class RequestQueue {
    private weak var apiClient: CobaltClient!
    private(set) var requests: [CobaltRequest] = []
    private var _map: [CobaltRequest: PassthroughSubject<CobaltResponse, CobaltError>] = [:]

    var count: Int {
        return requests.count
    }
    
    var isEmpty: Bool {
        return count == 0
    }

    init(client: CobaltClient) {
        self.apiClient = client
    }

    func add(_ request: CobaltRequest) {
        if requests.contains(request) {
            return
        }
        _map[request] = PassthroughSubject<CobaltResponse, CobaltError>()
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

    func publisher(of request: CobaltRequest) -> AnyPublisher<CobaltResponse, CobaltError>? {
        return _map[request]?.eraseToAnyPublisher()
    }

    func handle(request: CobaltRequest) {
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
        }, receiveValue: { response in
            subject?.send(response)
        }).store(in: &apiClient.cancellables)
    }
}
