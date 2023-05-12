//
//  FragmentCache.swift
//  Watt
//
//  Created by David Albert on 5/12/23.
//

import Foundation

extension LayoutManager {
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

        func fragment(at location: Location) -> LayoutFragment? {
            guard let index = fragments.firstIndex(where: { $0.textRange.lowerBound == location }) else {
                return nil
            }

            return fragments[index]
        }
    }
}
