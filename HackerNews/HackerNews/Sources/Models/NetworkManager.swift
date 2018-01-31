//
//  NetworkManager.swift
//  HackerNews
//
//  Created by Andrey Sak on 1/30/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import Foundation

protocol NetworkManager {
    func getRequest(withURLString urlString: String,
                    completion: @escaping(_ data: Data?, _ error: Error?) -> Swift.Void) -> RequestHanlder?
    func getImageRequest(withURLString urlString: String,
                         completion: @escaping(_ data: Data?, _ error: Error?) -> Swift.Void) -> RequestHanlder?
}

class RequestHanlder {
    var cancel: (() -> ())?
}

class NetworkManagerImpl : NetworkManager {
    
    private enum Constants {
        static let defaultRequestTimeInterval: TimeInterval = 60.0
    }
    
    private enum NetworkError : Error {
        case badRequest
        
        var localizedDescription: String {
            switch self {
            case .badRequest:
                return "Bad request"
            }
        }
    }
    
    private enum HTTPMethod : String {
        case get = "GET"
    }
    
    private let session: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
    }
    
    // MARK: - NetworkManager
    
    func getRequest(withURLString urlString: String,
                    completion: @escaping (Data?, Error?) -> Swift.Void) -> RequestHanlder? {
        return performRequest(withURLString: urlString, httpMethod: .get, completion: completion)
    }
    
    func getImageRequest(withURLString urlString: String,
                         completion: @escaping (Data?, Error?) -> Swift.Void) -> RequestHanlder? {
        return performRequest(withURLString: urlString, httpMethod: .get, cachePolicy: .returnCacheDataElseLoad, completion: completion)
    }
    
    private func performRequest(withURLString urlString: String,
                        httpMethod: HTTPMethod,
                        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                        completion: @escaping (_ data: Data?, _ error: Error?) -> Swift.Void) -> RequestHanlder? {
        
        guard let url = URL(string: urlString) else {
            completion(nil, NetworkError.badRequest)
            return nil
        }
        
        var urlRequest = URLRequest(url: url,
                                    cachePolicy: cachePolicy,
                                    timeoutInterval: Constants.defaultRequestTimeInterval)
        urlRequest.httpMethod = httpMethod.rawValue
        
        let task = self.session.dataTask(with: urlRequest) { (data, urlResponse, error) in
            completion(data, error)
        }
        
        task.resume()
        
        let requestHandler = RequestHanlder()
        requestHandler.cancel = {
            task.cancel()
        }
        
        return requestHandler
    }
}
