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

extension Collection {
    func index(after i: Index, clampedTo upperBound: Index) -> Index {
        index(i, offsetBy: 1, limitedBy: upperBound) ?? upperBound
    }

    func index(_ i: Index, offsetBy distance: Int, clampedTo limit: Index) -> Index {
        index(i, offsetBy: distance, limitedBy: limit) ?? limit
    }
}

extension BidirectionalCollection {
    func index(before i: Index, clampedTo lowerBound: Index) -> Index {
        index(i, offsetBy: -1, limitedBy: lowerBound) ?? lowerBound
    }
}

extension Range where Bound == Int {
    init(_ range: Range<String.Index> , in string: String) {
        let start = string.utf8.distance(from: string.utf8.startIndex, to: range.lowerBound)
        let end = string.utf8.distance(from: string.utf8.startIndex, to: range.upperBound)

        self.init(uncheckedBounds: (start, end))
    }
}
