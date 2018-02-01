//
//  StorySource.swift
//  HackerNews
//
//  Created by Andrey Sak on 1/30/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import Foundation

enum StorySource {
    case new
    case top
    case best
}

extension StorySource {
    var localizedName: String {
        switch self {
        case .new:
            return "New".localized.capitalized
        case .top:
            return "Top".localized.capitalized
        case .best:
            return "Best".localized.capitalized
        }
    }
}
