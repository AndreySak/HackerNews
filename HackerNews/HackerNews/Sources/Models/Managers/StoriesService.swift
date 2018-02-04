//
//  StoriesService.swift
//  HackerNews
//
//  Created by Andrey Sak on 1/30/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import Foundation

protocol StoriesService {
    func getStoriesList(storySource: StorySource, completion: @escaping (_ storyIds: [Int]?, _ error: Error?) -> Swift.Void)
    func getStory(byStoryId storyId: Int, completion: @escaping (_ story: Story?) -> Swift.Void) -> RequestHanlder?
}

class StoriesServiceImpl : StoriesService {
    
    private enum Constants {
        static let baseServerURL: String = "https://hacker-news.firebaseio.com"
        static let newStoriesPath: String = "v0/newstories.json"
        static let topStoriesPath: String = "v0/topstories.json"
        static let bestStoriesPath: String = "v0/beststories.json"
    }
    
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func getStoriesList(storySource: StorySource, completion: @escaping (_ storyIds: [Int]?, _ error: Error?) -> Swift.Void) {
        let storiesPath = getStoriesPath(fromStorySource: storySource)
        let urlString = "\(Constants.baseServerURL)/\(storiesPath)"
        _ = networkManager.getRequest(withURLString: urlString, cachePolicy: .reloadIgnoringLocalCacheData) { (responseData, error) in
            if let error = error {
                completion(nil, error)
            } else if let storyIdsData = responseData {
                do {
                    let storyIdsAny = try JSONSerialization.jsonObject(with: storyIdsData)
                    completion(storyIdsAny as? [Int], error)
                } catch {
                    completion(nil, error)
                }
            } else {
                completion(nil, nil)
            }
        }
    }
    
    func getStory(byStoryId storyId: Int, completion: @escaping (_ story: Story?) -> Swift.Void) -> RequestHanlder? {
        let storyURLString = "\(Constants.baseServerURL)/v0/item/\(storyId).json"
        return networkManager.getRequest(withURLString: storyURLString) { (storyData, error) in            
            guard let storyData = storyData else {
                completion(nil)
                return
            }
            
            do {
                let story = try JSONDecoder().decode(Story.self, from: storyData)
                completion(story)
            } catch {
                completion(nil)
                print(error)
            }
        }
    }
    
    private func getStoriesPath(fromStorySource storySource: StorySource) -> String {
        var storiesPath: String = String.emptyString
        
        switch storySource {
        case .new:
            storiesPath = Constants.newStoriesPath
        case .top:
            storiesPath = Constants.topStoriesPath
        case .best:
            storiesPath = Constants.bestStoriesPath
        }
        
        return storiesPath
    }
}
