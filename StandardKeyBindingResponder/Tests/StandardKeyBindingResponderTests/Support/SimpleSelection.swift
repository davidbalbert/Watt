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

enum Granularity: InitializableFromGranularity {
    case character
    case word
    case line
    case paragraph

    init(_ granularity: StandardKeyBindingResponder.Granularity) {
        switch granularity {
        case .character: self = .character
        case .word: self = .word
        case .line: self = .line
        case .paragraph: self = .paragraph
        }
    }
}

struct SimpleSelection: Equatable {
    let range: Range<String.Index>
    let affinity: Affinity
    let granularity: Granularity
    let xOffset: CGFloat?

    init(range: Range<String.Index>, affinity: Affinity, granularity: Granularity, xOffset: CGFloat?) {
        self.range = range
        self.affinity = affinity
        self.granularity = granularity
        self.xOffset = xOffset
    }
}

extension SimpleSelection: NavigableSelection {
    init(caretAt index: String.Index, affinity: Affinity, granularity: Granularity, xOffset: CGFloat? = nil) {
        self.init(range: index..<index, affinity: affinity, granularity: granularity, xOffset: xOffset)
    }

    init(anchor: String.Index, head: String.Index, granularity: Granularity, xOffset: CGFloat? = nil) {
        precondition(anchor != head, "anchor and head must be different")

        let i = min(anchor, head)
        let j = max(anchor, head)
        let affinity: Affinity = anchor < head ? .downstream : .upstream

        self.init(range: i..<j, affinity: affinity, granularity: granularity, xOffset: xOffset)
    }
}
