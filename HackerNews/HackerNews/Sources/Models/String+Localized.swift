//
//  String+Localized.swift
//  HackerNews
//
//  Created by Andrey Sak on 2/1/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import Foundation

extension String {
    static let emptyString: String = ""
    
    var localized: String {
        return NSLocalizedString(self, comment: String.emptyString)
    }
}
