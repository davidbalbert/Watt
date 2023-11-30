//
//  Foundation+Extensions.swift
//
//
//  Created by David Albert on 11/8/23.
//

import Foundation

extension StringProtocol {
    func index(at offset: Int) -> Index {
        index(startIndex, offsetBy: offset)
    }
}

extension Range where Bound == Int {
    init(_ range: Range<String.Index> , in string: String) {
        let start = string.utf8.distance(from: string.utf8.startIndex, to: range.lowerBound)
        let end = string.utf8.distance(from: string.utf8.startIndex, to: range.upperBound)

        self.init(uncheckedBounds: (start, end))
    }
}
