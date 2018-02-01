//
//  ReusableView.swift
//  HackerNews
//
//  Created by Andrey Sak on 2/1/18.
//  Copyright © 2018 Itransition. All rights reserved.
//

protocol ReusableView: class {}

extension ReusableView {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}
