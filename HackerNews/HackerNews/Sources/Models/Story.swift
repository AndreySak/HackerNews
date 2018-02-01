//
//  Story.swift
//  HackerNews
//
//  Created by Andrey Sak on 1/30/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

import Foundation

class Story : Codable {
    private enum CodingKeys: String, CodingKey {
        case creator = "by"
        case descendants
        case id
        case kids
        case score
        case time
        case title
        case type
        case url
        case text
    }
        
    let id: Int
    let creator: String?
    let descendants: Int?
    let kids: [Int]?
    let score: Int?
    let time: TimeInterval?
    let title: String?
    let type: String?
    let url: URL?
    let text: String?
    
    init(id: Int) {
        self.id = id
        
        creator = nil
        descendants = nil
        kids = nil
        score = nil
        time = nil
        title = nil
        type = nil
        url = nil
        text = nil
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try values.decode(Int.self, forKey: .id)
        creator = try? values.decode(String.self, forKey: .creator)
        descendants = try? values.decode(Int.self, forKey: .descendants)
        kids = try? values.decode(Array<Int>.self, forKey: .kids)
        score = try? values.decode(Int.self, forKey: .score)
        time = try? values.decode(Double.self, forKey: .time)
        title = try? values.decode(String.self, forKey: .title)
        type = try? values.decode(String.self, forKey: .type)
        url = try? values.decode(URL.self, forKey: .url)
        text = try? values.decode(String.self, forKey: .text)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try? container.encode(creator, forKey: .creator)
        try? container.encode(descendants, forKey: .descendants)
        try? container.encode(kids, forKey: .kids)
        try? container.encode(score, forKey: .score)
        try? container.encode(time, forKey: .time)
        try? container.encode(title, forKey: .title)
        try? container.encode(type, forKey: .type)
        try? container.encode(url, forKey: .url)
        try? container.encode(text, forKey: .text)
    }
}

extension Story : Hashable {
    var hashValue: Int {
        return id
    }
    
    static func ==(lhs: Story, rhs: Story) -> Bool {
        return lhs.id == rhs.id
    }
}
