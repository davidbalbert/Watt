//
//  FragmentCache.swift
//  Watt
//
//  Created by David Albert on 5/12/23.
//

import Foundation

struct FragmentCache {
    // stores fragments in order of their location
    // before each layout, we remove fragments that aren't in the viewport
    // otherwise we just let the cache grown unbounded
    var fragments: [LayoutFragment]

    init() {
        fragments = []
    }

    mutating func add(_ fragment: LayoutFragment) {
        // find the appropriate index to insert the fragment

        guard let index = fragments.firstIndex(where: { $0.textRange.lowerBound >= fragment.textRange.lowerBound }) else {
            fragments.append(fragment)
            return
        }

        fragments.insert(fragment, at: index)
    }

    mutating func removeFragments(before position: CGPoint) {
        guard let index = fragments.firstIndex(where: { $0.position.y >= position.y }) else {
            fragments = []
            return
        }

        fragments.removeSubrange(..<index)
    }

    mutating func removeFragments(after position: CGPoint) {
        guard let index = fragments.firstIndex(where: { $0.position.y > position.y }) else {
            return
        }

        fragments.removeSubrange(index...)
    }


    mutating func removeAll() {
        fragments = []
    }

    func fragment(at location: String.Index) -> LayoutFragment? {
        var low = 0
        var high = fragments.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let fragment = fragments[mid]

            if fragment.textRange.lowerBound < location {
                low = mid + 1
            } else if fragment.textRange.lowerBound > location {
                high = mid - 1
            } else {
                return fragment
            }
        }

        return nil
    }
}
