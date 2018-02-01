//
//  HTMLToAttributedStringConverter.swift
//  HackerNews
//
//  Created by Andrey Sak on 1/31/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import Foundation

class HTMLToAttributedStringConverter {
    class func convert(_ htmlText: String?) -> NSAttributedString? {
        guard let htmlText = htmlText else {
            return nil
        }
        
        var attributedText: NSAttributedString?
        
        if let htmlData = htmlText.data(using: String.Encoding.unicode) {
            do {
                attributedText = try NSAttributedString(data: htmlData,
                                                        options: [.documentType: NSAttributedString.DocumentType.html],
                                                        documentAttributes: nil)
            } catch {
                print("Couldn't translate \(htmlText): \(error.localizedDescription) ")
            }
        }
        
        return attributedText
    }
}
