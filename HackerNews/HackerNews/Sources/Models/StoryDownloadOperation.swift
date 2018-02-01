//
//  StoryDownloadOperation.swift
//  HackerNews
//
//  Created by Andrey Sak on 2/1/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import UIKit

open class AsyncOperation: Operation {
    public enum State: String {
        case ready, executing, finished
        
        fileprivate var keyPath: String {
            return "is" + rawValue.capitalized
        }
    }
    
    public var state = State.ready {
        willSet {
            willChangeValue(forKey: newValue.keyPath)
            willChangeValue(forKey: state.keyPath)
        }
        didSet {
            didChangeValue(forKey: oldValue.keyPath)
            didChangeValue(forKey: state.keyPath)
        }
    }
}


extension AsyncOperation {
    // NSOperation Overrides
    override open var isReady: Bool {
        return super.isReady && state == .ready
    }
    
    override open var isExecuting: Bool {
        return state == .executing
    }
    
    override open var isFinished: Bool {
        return state == .finished
    }
    
    override open var isAsynchronous: Bool {
        return true
    }
    
    override open func start() {
        if isCancelled {
            state = .finished
            return
        }
        
        main()
        state = .executing
    }
    
    open override func cancel() {
        super.cancel()
        state = .finished
    }
}

class StoryDownloadOperation : AsyncOperation {
    var story: Story?
    
    private var requestHandler: RequestHanlder?
    private let storyId: Int
    private let storiesService: StoriesService
    
    init(storyId: Int, storiesService: StoriesService) {
        self.storyId = storyId
        self.storiesService = storiesService
    }
    
    override func main() {
        guard !self.isCancelled else {
            return
        }
        
        requestHandler = storiesService.getStory(byStoryId: self.storyId) { [weak self] story in
            guard let strongSelf = self,
                !strongSelf.isCancelled else {
                    return
            }
            
            strongSelf.story = story
            strongSelf.state = .finished
        }
    }
    
    override func cancel() {
        requestHandler?.cancel?()
        super.cancel()
    }
}

class StoryImageDownloadOperation : AsyncOperation {
    var resultImage: UIImage?
    
    let storyURL: URL
    
    private var requestHandler: RequestHanlder?
    private let imageLoader: ImageLoader
    
    init(storyURL: URL, imageLoader: ImageLoader) {
        self.storyURL = storyURL
        self.imageLoader = imageLoader
    }
    
    override func main() {
        guard !self.isCancelled else {
            return
        }
        
        requestHandler = getStorySourceImage(fromURL: storyURL, completion: { [weak self] image in
            guard let strongSelf = self,
                !strongSelf.isCancelled else {
                    return
            }
            
            strongSelf.resultImage = image
            strongSelf.state = .finished
        })
    }
    
    override func cancel() {
        requestHandler?.cancel?()
        super.cancel()
    }
    
    private func getStorySourceImage(fromURL url: URL?, completion: @escaping (UIImage?) -> Swift.Void) -> RequestHanlder? {
        guard let url = url else {
            return nil
        }
        
        let siteIconUrls = SiteIconURLDecoder.decodeFromURL(url)
        guard let firstSiteIconURL = siteIconUrls.first else {
            completion(nil)
            return nil
        }
        
        return loadSiteImage(fromURL: firstSiteIconURL, siteIconUrls: siteIconUrls) { image in
                                completion(image)
        }
    }
    
    private func loadSiteImage(fromURL url: URL, siteIconUrls: [URL],
                               completion: @escaping (UIImage?)->()) -> RequestHanlder? {
        return imageLoader.loadImage(fromURLString: url.absoluteString) { [weak self] (image, _) in
            guard let strongSelf = self else {
                completion(nil)
                return
            }
            
            if let image = image {
                completion(image)
            } else {
                let siteIconUrlsWithoutCurrent = siteIconUrls.filter({ siteIconURL -> Bool in
                    return siteIconURL != url
                })
                
                guard let nextSiteIconURL = siteIconUrlsWithoutCurrent.first else {
                    completion(nil)
                    return
                }
                
                strongSelf.requestHandler = strongSelf.loadSiteImage(fromURL: nextSiteIconURL,
                                                                     siteIconUrls: siteIconUrlsWithoutCurrent,
                                                                     completion: completion)
            }
        }
    }
}
