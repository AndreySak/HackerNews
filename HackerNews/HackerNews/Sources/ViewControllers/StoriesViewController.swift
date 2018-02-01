//
//  StoriesViewController.swift
//  HackerNews
//
//  Created by Andrey Sak on 1/30/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import UIKit

class DownloadOperations {
    let storiesQueue: OperationQueue
    let storiesImageQueue: OperationQueue
    
    init() {
        storiesQueue = OperationQueue()
        storiesQueue.name = "Download stories queue"
        storiesQueue.maxConcurrentOperationCount = 10
        
        storiesImageQueue = OperationQueue()
        storiesImageQueue.name = "Download stories images queue"
        storiesImageQueue.maxConcurrentOperationCount = 10
    }
}

class StoriesViewController : UIViewController, UITableViewDataSource, UITableViewDelegate {
    private static let storiesSources: [StorySource] = [.new, .top, .best]
    private static let defaultSelectedStorySource: StorySource = .new
    private static let invalidSegmentedControllIndex: Int = -1
    private static let storiesPageCount: Int = 20
    private static let storyRowHeight: CGFloat = 60
    private static let storiesTableViewFooterHeight: CGFloat = 60
    
    @IBOutlet weak var storiesTableView: UITableView!
    @IBOutlet weak var storiesSourceSegmentedControl: UISegmentedControl!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    private var refreshControl = UIRefreshControl()
    
    private var storiesService: StoriesService!
    private var imageLoader: ImageLoader!
    private var networkManager: NetworkManager!
    
    private var storyIds: [Int] = []
    private var stories: [Story] = []
    private var storiesImages: [Story : UIImage?] = [:]
    private let downloadOperaions = DownloadOperations()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        storiesTableView.rowHeight = StoriesViewController.storyRowHeight
        storiesTableView.tableFooterView = UIView()
        storiesTableView.tableHeaderView = UIView()
        
        networkManager = NetworkManagerImpl()
        storiesService = StoriesServiceImpl(networkManager: networkManager)
        imageLoader = ImageLoaderIml(networkManager: networkManager)
        
        configureRefreshControl()
        
        let defaultSelectedStorySource = StoriesViewController.defaultSelectedStorySource
        configureSegmentedControl(withStorySources: StoriesViewController.storiesSources,
                                  selectedStorySource: defaultSelectedStorySource)
        getStoriesIds(withStorySource: defaultSelectedStorySource)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPostDetails",
            let storyDetailsVC = segue.destination as? StoryDetailViewController,
            let story = sender as? Story {
            storyDetailsVC.setupStory(story)
        }
    }
    
    @objc func refresh(sender: AnyObject) {
        let selectedSourceIndex = storiesSourceSegmentedControl.selectedSegmentIndex
        
        guard selectedSourceIndex != StoriesViewController.invalidSegmentedControllIndex else {
            return
        }
        
        let selectedStorySource = StoriesViewController.storiesSources[selectedSourceIndex]
        
        getStoriesIds(withStorySource: selectedStorySource)
    }
    
    @IBAction func didNewStorySourceSelected(_ sender: Any) {
        guard let segmentedControl = sender as? UISegmentedControl else {
            return
        }
        
        let selectedSourceIndex = segmentedControl.selectedSegmentIndex
        
        guard selectedSourceIndex != StoriesViewController.invalidSegmentedControllIndex else {
            return
        }
        
        let selectedStorySource = StoriesViewController.storiesSources[selectedSourceIndex]
        clearDataAndReload()
        getStoriesIds(withStorySource: selectedStorySource)
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "StoryTableViewCell", for: indexPath)
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedStory = stories[indexPath.row]
        performSegue(withIdentifier: "showPostDetails", sender: selectedStory)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? StoryTableViewCell else {
            return
        }
        
        let story = stories[indexPath.row]
        cell.storyTitle = story.title
        if let storyImage = storiesImages[story] {
            cell.sourceImage = storyImage
        } else if let storyURL = story.url {
            let storyImageDownloadOperation = StoryImageDownloadOperation(storyURL: storyURL,
                                                                          imageLoader: imageLoader)
            storyImageDownloadOperation.completionBlock = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.storiesImages[story] = storyImageDownloadOperation.resultImage
                cell.sourceImage = storyImageDownloadOperation.resultImage
            }
            downloadOperaions.storiesQueue.addOperation(storyImageDownloadOperation)
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard !stories.isEmpty else {
            return
        }
        
        let story = stories[indexPath.row]
        if let storyURL = story.url,
            let storyImageDownloadOperation = downloadOperaions.storiesImageQueue.operations.first(where: { operation -> Bool in
                guard let downloadStoryImageOperation = operation as? StoryImageDownloadOperation else {
                    return false
                }
                
                return downloadStoryImageOperation.storyURL == storyURL
            }) {
            storyImageDownloadOperation.cancel()
        }
    }
    
    private func configureRefreshControl() {
        storiesTableView.refreshControl = refreshControl
        refreshControl.addTarget(self,
                                 action: #selector(StoriesViewController.refresh),
                                 for: .valueChanged)
    }
    
    private func configureSegmentedControl(withStorySources storySources: [StorySource], selectedStorySource: StorySource) {
        storiesSourceSegmentedControl.removeAllSegments()
        storiesSourceSegmentedControl.setTitleTextAttributes([NSAttributedStringKey.foregroundColor : UIColor.white], for: .selected)
        
        storySources.enumerated().forEach { (index, storySource) in
            storiesSourceSegmentedControl.insertSegment(withTitle: storySource.localizedName,
                                                        at: index,
                                                        animated: false)
        }
        
        if let selectedStorySourceIndex = storySources.index(of: selectedStorySource) {
            storiesSourceSegmentedControl.selectedSegmentIndex = selectedStorySourceIndex
        }
    }
    
    private func getStoriesIds(withStorySource storySource: StorySource) {
        setActivityIndicatorState(hidden: false)
        storiesService.getStoriesList(storySource: storySource) { [weak self] (storyIds, _) in
            guard let strongSelf = self else {
                return
            }

            if let storyIds = storyIds {
                strongSelf.storyIds = storyIds
                strongSelf.getStories(withStoryIds: [Int](storyIds[..<StoriesViewController.storiesPageCount]))
            }
        }
    }
    
    private func getStories(withStoryIds storyIds: [Int]) {
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
            self.downloadOperaions.storiesQueue.addOperations(storyDownloadOperations,
                                                               waitUntilFinished: true)
            self.disableRefreshControlIfNeeded()
            self.setActivityIndicatorState(hidden: true)
            let startIndex = self.stories.count
            self.stories.append(contentsOf: stories)
            DispatchQueue.main.async {
                (self.storiesTableView.tableFooterView as? UIActivityIndicatorView)?.stopAnimating()
                var indexPaths: [IndexPath] = []
                for i in startIndex..<self.stories.count {
                    indexPaths.append(IndexPath(row: i, section: 0))
                }
                self.storiesTableView.insertRows(at: indexPaths, with: .automatic)
            }
        }
    }
    
    private func disableRefreshControlIfNeeded() {
        DispatchQueue.main.async {
            if self.refreshControl.isRefreshing {
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    private func clearDataAndReload() {
        DispatchQueue.main.async {
            self.storyIds = []
            self.stories = []
            self.storiesTableView.reloadData()
        }
    }
    
    private func setActivityIndicatorState(hidden isHidden: Bool) {
        DispatchQueue.main.async {
            self.activityIndicatorView.isHidden = isHidden
            if isHidden {
                self.activityIndicatorView.stopAnimating()
            } else {
                self.activityIndicatorView.startAnimating()
            }
        }
    }
    
    private func loadMoreData() {
        let bottomViewRect = CGRect(x: 0.0,
                                    y: 0.0,
                                    width: storiesTableView.frame.width,
                                    height: StoriesViewController.storiesTableViewFooterHeight)
        var footerView: UIView!
        
        if stories.count < storyIds.count {
            let acitivtyIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .gray)
            acitivtyIndicatorView.frame = bottomViewRect
            acitivtyIndicatorView.startAnimating()
            acitivtyIndicatorView.hidesWhenStopped = true
            footerView = acitivtyIndicatorView
            
            loadNextStories()
        } else {
            let noMoreDataLabel = UILabel(frame: bottomViewRect)
            noMoreDataLabel.text = "No more stories"
            noMoreDataLabel.textAlignment = .center
            
            footerView = noMoreDataLabel
        }
        
        self.storiesTableView.tableFooterView = acitivtyIndicatorView
    }
    
    private func loadNextStories() {
        var upperBoundForStoryIds = stories.count + StoriesViewController.storiesPageCount
        if upperBoundForStoryIds > storyIds.count {
            upperBoundForStoryIds = storyIds.count
        }
        getStories(withStoryIds: [Int](storyIds[stories.count..<upperBoundForStoryIds]))
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y + scrollView.frame.size.height == scrollView.contentSize.height {
            loadMoreData()
        }
    }
}
