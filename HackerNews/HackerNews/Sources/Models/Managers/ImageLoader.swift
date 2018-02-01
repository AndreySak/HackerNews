//
//  ImageLoader.swift
//  HackerNews
//
//  Created by Andrey Sak on 1/31/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import UIKit

protocol ImageLoader {
    func loadImage(fromURLString urlString: String, completion: @escaping (UIImage?, Error?) -> Swift.Void) -> RequestHanlder?
}

class ImageLoaderIml : ImageLoader {
    let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func loadImage(fromURLString urlString: String, completion: @escaping (UIImage?, Error?) -> Swift.Void) -> RequestHanlder? {
        return networkManager.getImageRequest(withURLString: urlString) { (imageData, error) in
            if let imageData = imageData,
                let image = UIImage(data: imageData) {
                completion(image, nil)
            } else {
                completion(nil, error)
            }
        }
    }
}
