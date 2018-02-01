//
//  StoriesViewController.swift
//  HackerNews
//
//  Created by Andrey Sak on 1/30/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import UIKit

class StoriesViewController : UIViewController, UITableViewDataSource, UITableViewDelegate {
    private enum Constants {
        static let storiesSources: [StorySource] = [.new, .top, .best]
        static let defaultSelectedStorySource: StorySource = .new
        static let invalidSegmentedControllIndex: Int = -1
        static let storiesPageCount: Int = 20
        static let storyRowHeight: CGFloat = 60
        static let storiesTableViewFooterHeight: CGFloat = 60
        static let noMoreStoriesMessage: String = "No more stories"
        static let showPostDetailsSegueIdentifier: String = "showPostDetails"
    }
    
    @IBOutlet weak var storiesTableView: UITableView!
    @IBOutlet weak var storiesSourceSegmentedControl: UISegmentedControl!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    private var refreshControl = UIRefreshControl()
    
    private var storiesService: StoriesService!
    private var networkManager: NetworkManager!
    
    private var storiesDownloadManager: StoriesDownloadManager!
    
    private var storyIds: [Int] = []
    private var stories: [Story] = []
    private var storiesImages: [Story : UIImage?] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        storiesTableView.rowHeight = Constants.storyRowHeight
        storiesTableView.tableFooterView = UIView()
        storiesTableView.tableHeaderView = UIView()
        
        networkManager = NetworkManagerImpl()
        storiesService = StoriesServiceImpl(networkManager: networkManager)
        let imageLoader = ImageLoaderIml(networkManager: networkManager)
        storiesDownloadManager = StoriesDownloadManager(storiesService: storiesService, imageLoader: imageLoader)
        
        configureRefreshControl()
        
        let defaultSelectedStorySource = Constants.defaultSelectedStorySource
        configureSegmentedControl(withStorySources: Constants.storiesSources,
                                  selectedStorySource: defaultSelectedStorySource)
        getStoriesIds(withStorySource: defaultSelectedStorySource)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Constants.showPostDetailsSegueIdentifier,
            let storyDetailsVC = segue.destination as? StoryDetailViewController,
            let story = sender as? Story {
            storyDetailsVC.setupStory(story)
        }
    }
    
    @objc func refresh(sender: AnyObject) {
        let selectedSourceIndex = storiesSourceSegmentedControl.selectedSegmentIndex
        
        guard selectedSourceIndex != Constants.invalidSegmentedControllIndex else {
            return
        }
        
        let selectedStorySource = Constants.storiesSources[selectedSourceIndex]
        
        getStoriesIds(withStorySource: selectedStorySource)
    }
    
    @IBAction func didNewStorySourceSelected(_ sender: Any) {
        guard let segmentedControl = sender as? UISegmentedControl else {
            return
        }
        
        let selectedSourceIndex = segmentedControl.selectedSegmentIndex
        
        guard selectedSourceIndex != Constants.invalidSegmentedControllIndex else {
            return
        }
        
        let selectedStorySource = Constants.storiesSources[selectedSourceIndex]
        clearDataAndReload()
        getStoriesIds(withStorySource: selectedStorySource)
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: StoryTableViewCell.reuseIdentifier, for: indexPath)
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedStory = stories[indexPath.row]
        performSegue(withIdentifier: Constants.showPostDetailsSegueIdentifier, sender: selectedStory)
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
            storiesDownloadManager.downloadStoryImage(withStoryURL: storyURL) { [weak self] storySourceImage in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.storiesImages[story] = storySourceImage
                cell.sourceImage = storySourceImage
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard !stories.isEmpty else {
            return
        }
        
        let story = stories[indexPath.row]
        if let storyURL = story.url {
            storiesDownloadManager.cancelDownloadStoryImage(withStoryURL: storyURL)
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
        storiesSourceSegmentedControl.setTitleTextAttributes([NSAttributedStringKey.foregroundColor : UIColor.white],
                                                             for: .selected)
        
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
                strongSelf.getStories(withStoryIds: [Int](storyIds[..<Constants.storiesPageCount]))
            }
        }
    }
    
    private func getStories(withStoryIds storyIds: [Int]) {
        storiesDownloadManager.downloadStories(withStoryIds: storyIds) { [weak self] stories in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.disableRefreshControlIfNeeded()
            strongSelf.setActivityIndicatorState(hidden: true)
            let newStoriesStartIndex = strongSelf.stories.count
            strongSelf.stories.append(contentsOf: stories)
            
            DispatchQueue.main.async {
                (strongSelf.storiesTableView.tableFooterView as? UIActivityIndicatorView)?.stopAnimating()
                var indexPaths: [IndexPath] = []
                for i in newStoriesStartIndex..<strongSelf.stories.count {
                    indexPaths.append(IndexPath(row: i, section: 0))
                }
                strongSelf.storiesTableView.insertRows(at: indexPaths, with: .automatic)
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
                                    height: Constants.storiesTableViewFooterHeight)
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
            noMoreDataLabel.text = Constants.noMoreStoriesMessage
            noMoreDataLabel.textAlignment = .center
            
            footerView = noMoreDataLabel
        }
        
        storiesTableView.tableFooterView = footerView
    }
    
    private func loadNextStories() {
        var upperBoundForStoryIds = stories.count + Constants.storiesPageCount
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
