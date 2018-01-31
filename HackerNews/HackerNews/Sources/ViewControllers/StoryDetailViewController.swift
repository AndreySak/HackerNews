//
//  StoryDetailViewController.swift
//  HackerNews
//
//  Created by Andrey Sak on 1/30/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import UIKit

class StoryDetailViewController: UIViewController {
    private static let newsTextNotFound: String = "There is currently no description for this piece of news, check it out later"
    private static let storyTextFontSize: CGFloat = 17.0
    
    @IBOutlet weak var storyTitleLabel: UILabel!
    @IBOutlet weak var storyTextLabel: UILabel!
    @IBOutlet weak var newsTextNotFoundImageView: UIImageView!
    
    private var story: Story!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        storyTitleLabel.text = story.title
        if let attributedText = HTMLToAttributedStringConverter.convert(story?.text) {
            let mutableAttributedText = NSMutableAttributedString(attributedString: attributedText)
            let fullRange = NSMakeRange(0, mutableAttributedText.length)
            mutableAttributedText.setAttributes([.font : UIFont.systemFont(ofSize: StoryDetailViewController.storyTextFontSize)],
                                                range: fullRange)
            storyTextLabel.attributedText = mutableAttributedText
            storyTextLabel.textAlignment = .natural
            newsTextNotFoundImageView.isHidden = true
        } else {
            storyTextLabel.text = StoryDetailViewController.newsTextNotFound
        }
    }
    
    func setupStory(_ story: Story) {
        self.story = story
    }    
}
