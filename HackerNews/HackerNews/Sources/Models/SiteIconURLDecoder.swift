//
//  SiteIconURLDecoder.swift
//  HackerNews
//
//  Created by Andrey Sak on 1/31/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import Foundation

class SiteIconURLDecoder {
    private static let serverAddressRegexPattern: String = "^(?:www\\.)?(.*?)\\.(?:com|au\\.uk|co\\.in)"
    private static let siteIconNames: [String] = ["touchicon.ico", "favicon.ico", "touch-icon.ico", "fav-icon.ico"]
    
    class func decodeFromURL(_ url: URL) -> [URL] {
        let urlString = url.absoluteString
        
        guard let serverAddress = getRegexMatches(formUrlString: urlString).first else {
            return []
        }
        
        var resultUrls: [URL] = []
        
        SiteIconURLDecoder.siteIconNames.forEach { iconName in
            let iconURLString = "\(serverAddress)/\(iconName)"
            if let iconURL = URL(string: iconURLString) {
                resultUrls.append(iconURL)
            }
        }
        
        return resultUrls
    }
    
    private class func getRegexMatches(formUrlString urlString: String) -> [String] {
        do {
            
            let regex = try NSRegularExpression(pattern: SiteIconURLDecoder.serverAddressRegexPattern)
            let results = regex.matches(in: urlString,
                                        range: NSRange(urlString.startIndex..., in: urlString))
            
            var resultStrings: [String] = []
            
            results.forEach({ textCheckingResult in
                guard let urlStringRange = Range(textCheckingResult.range, in: urlString) else {
                    return
                }
                
                let resultString = String(urlString[urlStringRange])
                resultStrings.append(resultString)
            })
            
            return resultStrings
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}
