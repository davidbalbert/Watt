//
//  SimpleSelection.swift
//
//
//  Created by David Albert on 11/8/23.
//

import Foundation
import StandardKeyBindingResponder

// Implementations of NavigableSelection, SelectionNavigationDataSource, and InitializableFromAffinity
// used for testing.

struct SimpleSelection: Equatable {
    enum Affinity: InitializableFromAffinity {
        case upstream
        case downstream

        init(_ affinity: StandardKeyBindingResponder.Affinity) {
           switch affinity {
           case .upstream: self = .upstream
           case .downstream: self = .downstream
           }
        }
    }

    let range: Range<String.Index>
    let affinity: Affinity
    let xOffset: CGFloat?

    init(range: Range<String.Index>, affinity: Affinity, xOffset: CGFloat?) {
        self.range = range
        self.affinity = affinity
        self.xOffset = xOffset
    }
}

extension SimpleSelection: NavigableSelection {
    init(caretAt index: String.Index, affinity: Affinity, xOffset: CGFloat? = nil) {
        self.init(range: index..<index, affinity: affinity, xOffset: xOffset)
    }

    init(anchor: String.Index, head: String.Index, xOffset: CGFloat? = nil) {
        precondition(anchor != head, "anchor and head must be different")

        let i = min(anchor, head)
        let j = max(anchor, head)
        let affinity: Affinity = anchor < head ? .downstream : .upstream

        self.init(range: i..<j, affinity: affinity, xOffset: xOffset)
    }
}
