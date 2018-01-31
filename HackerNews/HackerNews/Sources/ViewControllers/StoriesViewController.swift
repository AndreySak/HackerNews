//
//  StoriesViewController.swift
//  HackerNews
//
//  Created by Andrey Sak on 1/30/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import UIKit

protocol StoryCellStateChaningDelegate : class {
    func didStoryTitleChanged(_ storyCellState: StoryCellState, withTitle title: String)
    func didStorySourceImageChanged(_ storyCellState: StoryCellState, withImage image: UIImage?)
}

struct StoryCellState {
    weak var changingStateDelegate: StoryCellStateChaningDelegate?
    
    var story: Story? {
        didSet {
            guard let storyTitle = story?.title else {
                return
            }
            
            changingStateDelegate?.didStoryTitleChanged(self, withTitle: storyTitle)
        }
    }
    
    var storySourceImage: UIImage? {
        didSet {
            changingStateDelegate?.didStorySourceImageChanged(self, withImage: storySourceImage)
        }
    }
}

class StoriesViewController : UIViewController, UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching {
    private static let storiesSources: [StorySource] = [.new, .top, .best]
    private static let defaultSelectedStorySource: StorySource = .new
    private static let invalidSegmentedControllIndex: Int = -1
    
    @IBOutlet weak var storiesTableView: UITableView!
    @IBOutlet weak var storiesSourceSegmentedControl: UISegmentedControl!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    private var refreshControl = UIRefreshControl()
    
    private var storiesService: StoriesService!
    private var imageLoader: ImageLoader!
    private var networkManager: NetworkManager!
    
    private var storyIds: [Int] = []
    private var storiesCellStates: [StoryCellState] = []
    private var storiesRequestHandlers: [RequestHanlder] = []
    private var imagesRequestHandlers: [RequestHanlder] = []
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        storiesTableView.prefetchDataSource = self
        storiesTableView.rowHeight = 60.0
        storiesTableView.tableFooterView = UIView()
        storiesTableView.tableHeaderView = UIView()
        
        networkManager = NetworkManagerImpl()
        storiesService = StoriesServiceImpl(networkManager: networkManager)
        imageLoader = ImageLoaderIml(networkManager: networkManager)
        
        configureRefreshControl()
        
        let defaultSelectedStorySource = StoriesViewController.defaultSelectedStorySource
        configureSegmentedControl(withStorySources: StoriesViewController.storiesSources,
                                  selectedStorySource: defaultSelectedStorySource)
        getStories(withStorySource: defaultSelectedStorySource)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UIApplication.shared.statusBarStyle = .lightContent
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
        
        getStories(withStorySource: selectedStorySource)
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
        storiesRequestHandlers.forEach { $0.cancel?() }
        imagesRequestHandlers.forEach { $0.cancel?() }
        getStories(withStorySource: selectedStorySource)
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return storiesCellStates.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "StoryTableViewCell", for: indexPath)
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedStory = storiesCellStates[indexPath.row].story
        performSegue(withIdentifier: "showPostDetails", sender: selectedStory)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? StoryTableViewCell else {
            return
        }
        
        storiesCellStates[indexPath.row].changingStateDelegate = cell
        let storyCellState = storiesCellStates[indexPath.row]
        let story = storyCellState.story
        cell.storyTitle = story?.title
        
        cell.sourceImage = storyCellState.storySourceImage
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if storiesCellStates.count > indexPath.row {
            storiesCellStates[indexPath.row].changingStateDelegate = nil
        }
        
        storiesRequestHandlers[indexPath.row].cancel?()
        imagesRequestHandlers[indexPath.row].cancel?()
    }
    
    // MARK: - UITableViewDataSourcePrefetching
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        indexPaths.forEach { indexPath in
            let storyId = storyIds[indexPath.row]
            fetchStories(withSpecifiedStoryIds: [storyId])
        }
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        indexPaths.forEach { indexPath in
            storiesRequestHandlers[indexPath.row].cancel?()
            imagesRequestHandlers[indexPath.row].cancel?()
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
    
    private func fetchStories(withSpecifiedStoryIds storyIds: [Int]) {
        storyIds.forEach { storyId in
            guard !storiesCellStates.contains(where: { storyCellState -> Bool in
                guard let story = storyCellState.story else {
                    return false
                }
                
                return story.id == storyId
            }),
                let indexOfStory = self.storyIds.index(of: storyId) else {
                    return
            }
            
            let storyRequestHandler = storiesService.getStory(byStoryId: storyId) { [weak self] story in
                guard let story = story,
                    let strongSelf = self,
                    strongSelf.storiesCellStates.count > indexOfStory else {
                        return
                }
                
                let imageRequestHandler = strongSelf.getStorySourceImage(fromURL: story.url, completion: { image in
                    guard strongSelf.storiesCellStates.count > indexOfStory else {
                        return
                    }
                    strongSelf.storiesCellStates[indexOfStory].storySourceImage = image
                })
                if let imageRequestHandler = imageRequestHandler {
                    strongSelf.imagesRequestHandlers[indexOfStory] = imageRequestHandler
                }
                
                strongSelf.storiesCellStates[indexOfStory].story = story
            }
            
            if let storyRequestHandler = storyRequestHandler {
                storiesRequestHandlers[indexOfStory] = storyRequestHandler
            }
        }
    }
    
    private func getStories(withStorySource storySource: StorySource) {
        setActivityIndicatorState(hidden: false)
        storiesService.getStoriesList(storySource: storySource) { [weak self] (storyIds, _) in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.disableRefreshControlIfNeeded()
            strongSelf.setActivityIndicatorState(hidden: true)
            
            if let storyIds = storyIds {
                strongSelf.storyIds = storyIds
                strongSelf.storiesCellStates = Array<StoryCellState>(repeating: StoryCellState(), count: storyIds.count)
                strongSelf.storiesRequestHandlers = Array<RequestHanlder>(repeating: RequestHanlder(), count: storyIds.count)
                strongSelf.imagesRequestHandlers = Array<RequestHanlder>(repeating: RequestHanlder(), count: storyIds.count)
                DispatchQueue.main.async {
                    strongSelf.storiesTableView.reloadData()
                    strongSelf.fetchStoriesForVisibleCells(storyIds)
                }
            } else {
                strongSelf.clearDataAndReload()
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
    
    private func fetchStoriesForVisibleCells(_ storyIds: [Int]) {
        if let visibleIndexPaths = storiesTableView.indexPathsForVisibleRows,
            let firstVisibleIndexPath = visibleIndexPaths.first,
            let lastVisibleIndexPath = visibleIndexPaths.last {
            let startIndex = firstVisibleIndexPath.row
            let endIndex = lastVisibleIndexPath.row
            DispatchQueue.global(qos: .userInitiated).async {
                let storyIdsForVisibleCells = storyIds[startIndex...endIndex]
                self.fetchStories(withSpecifiedStoryIds: Array<Int>(storyIdsForVisibleCells))
            }
        }
    }
    
    private func clearDataAndReload() {
        storyIds = []
        storiesCellStates = []
        DispatchQueue.main.async {
            self.storiesTableView.reloadData()
        }
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
    
    private func setActivityIndicatorState(hidden isHidden: Bool) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.5, animations: {
                self.activityIndicatorView.isHidden = isHidden
            })           
            
            if isHidden {
                self.activityIndicatorView.stopAnimating()
            } else {
                self.activityIndicatorView.startAnimating()
            }
        }
    }
    
    private func loadSiteImage(fromURL url: URL, siteIconUrls: [URL], completion: @escaping (UIImage?)->()) -> RequestHanlder? {
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
                
                _ = strongSelf.loadSiteImage(fromURL: nextSiteIconURL, siteIconUrls: siteIconUrlsWithoutCurrent, completion: completion)
            }
        }
    }
}
