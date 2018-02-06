//
//  StoriesDownloadManager.swift
//  HackerNews
//
//  Created by Andrey Sak on 2/1/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import UIKit

class StoriesDownloadManager {
    private let storiesQueue: OperationQueue
    private let storiesImageQueue: OperationQueue
    
    private let imageLoader: ImageLoader
    private let storiesService: StoriesService
    
    init(storiesService: StoriesService, imageLoader: ImageLoader) {
        self.storiesService = storiesService
        self.imageLoader = imageLoader
        
        storiesQueue = OperationQueue()
        storiesQueue.name = "Download stories queue"
        storiesQueue.maxConcurrentOperationCount = 10
        
        storiesImageQueue = OperationQueue()
        storiesImageQueue.name = "Download stories images queue"
        storiesImageQueue.maxConcurrentOperationCount = 10
    }
    
    func downloadStories(withStoryIds storyIds: [Int], completion: @escaping ([Story]) -> Swift.Void) {
        var stories: [Story] = []
        let storyDownloadOperations = storyIds.map({ storyId -> StoryDownloadOperation in
            let storyDownloadOperaion = StoryDownloadOperation(storyId: storyId,
                                                               storiesService: storiesService)
            storyDownloadOperaion.completionBlock = {
                if let story = storyDownloadOperaion.story {
                    stories.append(story)
                }
            }
            return storyDownloadOperaion
        })
        
        DispatchQueue.global(qos: .userInteractive).async {
            self.storiesQueue.addOperations(storyDownloadOperations, waitUntilFinished: true)
            completion(stories)
        }
    }
    
    func downloadStoryImage(withStoryURL storyURL: URL, completion: @escaping (UIImage?) -> Swift.Void) {
        let storyImageDownloadOperation = StoryImageDownloadOperation(storyURL: storyURL,
                                                                      imageLoader: imageLoader)
        storyImageDownloadOperation.completionBlock = {
            let resultImage = storyImageDownloadOperation.resultImage
            completion(resultImage)
        }
        storiesImageQueue.addOperation(storyImageDownloadOperation)
    }
    
    func cancelDownloadStoryImage(withStoryURL storyURL: URL) {
        guard let storyImageDownloadOperation = storiesImageQueue.operations.first(where: { operation -> Bool in
            guard let downloadStoryImageOperation = operation as? StoryImageDownloadOperation else {
                return false
            }
            
            return downloadStoryImageOperation.storyURL == storyURL
        }) else {
            return
        }
        print("storyImageDownloadOperation.cancel()")
        storyImageDownloadOperation.cancel()
    }
}
