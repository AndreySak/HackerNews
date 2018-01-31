//
//  StoryTableViewCell.swift
//  HackerNews
//
//  Created by Andrey Sak on 1/30/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import UIKit

class StoryTableViewCell : UITableViewCell, StoryCellStateChaningDelegate {
    private static let defaultSourceImage: UIImage = #imageLiteral(resourceName: "newspaper")
    
    @IBOutlet private weak var sourceImageView: UIImageView!
    @IBOutlet private weak var storyTitleLabel: UILabel!
    
    var sourceImage: UIImage? {
        didSet {
            DispatchQueue.main.async {
                self.sourceImageView.image = self.sourceImage ?? StoryTableViewCell.defaultSourceImage
            }
        }
    }
    
    var storyTitle: String? {
        didSet {
            DispatchQueue.main.async {
                self.storyTitleLabel.text = self.storyTitle
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        sourceImageView.layer.cornerRadius = 4.0
        sourceImageView.clipsToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        storyTitleLabel.text = nil
        sourceImageView.image = StoryTableViewCell.defaultSourceImage
    }
    
    func didStoryTitleChanged(_ storyCellState: StoryCellState, withTitle title: String) {
        DispatchQueue.main.async {
            self.storyTitleLabel.text = title
        }
    }
    
    func didStorySourceImageChanged(_ storyCellState: StoryCellState, withImage image: UIImage?) {
        DispatchQueue.main.async {
            if let image = image {
                self.sourceImageView.image = image
            } else {
                self.sourceImageView.image = StoryTableViewCell.defaultSourceImage
            }
        }
    }
}
