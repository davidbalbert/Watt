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
    //
    // This index returned by this method is undefined if the
    // value you're searching for is repeated in the
    // collection - it depends on the number of elements in the
    // collection in surprising ways.
    //
    // While you can use this method on collections that have
    // repeated elements, you must be sure you're not searching
    // for the repeated element before you use it.
    func firstIndexBinarySearch(of value: Element) -> (index: Index, found: Bool) {
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

extension RandomAccessCollection {
    func binarySearch(using comparator: (Element) -> ComparisonResult ) -> Element? {
        let (i, found) = firstIndexBinarySearch(using: comparator)

        if found {
            return self[i]
        } else {
            return nil
        }
    }

    func firstIndexBinarySearch(using comparator: (Element) -> ComparisonResult) -> (index: Index, found: Bool) {
        var low = startIndex
        var high = endIndex

        while low < high {
            let mid = index(low, offsetBy: distance(from: low, to: high) / 2)

            switch comparator(self[mid]) {
            case .orderedSame:
                return (mid, true)
            case .orderedAscending:
                low = index(after: mid)
            case .orderedDescending:
                high = mid
            }
        }

        return (low, false)
    }
}

extension Collection {
    func index(after i: Index, clampedTo upperBound: Index) -> Index {
        index(i, offsetBy: 1, limitedBy: upperBound) ?? upperBound
    }
}

extension BidirectionalCollection {
    func index(before i: Index, clampedTo lowerBound: Index) -> Index {
        index(i, offsetBy: -1, limitedBy: lowerBound) ?? lowerBound
    }
}
