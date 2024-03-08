//
//  Comparable+Extensions.swift
//  Watt
//
//  Created by David Albert on 12/23/23.
//

import Foundation

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }

    func compare(to other: Self) -> ComparisonResult {
        if self == other {
            return .orderedSame
        } else if self < other {
            return .orderedAscending
        } else {
            return .orderedDescending
        }
    }
}
