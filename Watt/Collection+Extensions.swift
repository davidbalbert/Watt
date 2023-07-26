//
//  Collection+Extensions.swift
//  Watt
//
//  Created by David Albert on 7/26/23.
//

import Foundation

extension RandomAccessCollection where Element: Comparable {
    // If found, returns the index of the element. Upon failure,
    // returns the index where the element would be inserted.
    func binarySearch(for value: Element) -> (index: Index, found: Bool) {
        var low = startIndex
        var high = endIndex

        while low < high {
            let mid = index(low, offsetBy: distance(from: low, to: high) / 2)
            if self[mid] == value {
                return (mid, true)
            } else if self[mid] < value {
                low = index(after: mid)
            } else {
                high = mid
            }
        }

        return (low, false)
    }
}
