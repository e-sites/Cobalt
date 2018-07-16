//
//  RequestQueue.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 02/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Promises
import Alamofire
import SwiftyJSON

class RequestQueue {
    private weak var apiClient: Client!
    private(set) var requests: [Request] = []
    private var _promiseMap: [Request: Promise<JSON>] = [:]

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
        _promiseMap[request] = Promise<JSON>.pending()
        requests.append(request)
        apiClient.logger?.verbose("Added to queue [\(count)]: \(request)")
    }

    func removeFirst() {
        if requests.isEmpty {
            return
        }
        let request = requests.removeFirst()
        _promiseMap.removeValue(forKey: request)
    }

    func next() {
        if let nextRequest = requests.first {
            handle(request: nextRequest)
        }
    }

    func clear() {
        _promiseMap.removeAll()
        requests.removeAll()
    }

    func promise(of request: Request) -> Promise<JSON>? {
        return _promiseMap[request]
    }

    func handle(request: Request) {
        let promise = self.promise(of: request)
        removeFirst()
        if promise == nil {
            return
        }
        
        apiClient.request(request) { result in
            switch result {
            case .success(let json):
                promise?.fulfill(json)
            case .failure(let error):
                promise?.reject(error)
            }
        }
    }
}
