//
//  APIRequestQueue.swift
//  Cobalt
//
//  Created by Bas van Kuijck on 02/05/2018.
//  Copyright © 2018 E-sites. All rights reserved.
//

import Foundation
import Promises
import Alamofire
import SwiftyJSON

class APIRequestQueue {
    private weak var apiClient: Cobalt!
    private(set) var requests: [APIRequest] = []
    private var _promiseMap: [APIRequest: Promise<JSON>] = [:]

    var count: Int {
        return requests.count
    }

    init(client: Cobalt) {
        self.apiClient = client
    }

    func add(_ request: APIRequest) {
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

    func promise(of request: APIRequest) -> Promise<JSON>? {
        return _promiseMap[request]
    }

    func handle(request: APIRequest) {
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
