//
//  Selection.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import Foundation
import StandardKeyBindingResponder

enum Affinity {
    case upstream
    case downstream
}

struct Selection {
    enum Granularity {
        case character
        case word
        case line  
        case paragraph      
    }

    let range: Range<Buffer.Index>
    // For caret, determines which side of a line wrap the caret is on.
    // For range, determins which the end is head, and which end is the anchor.
    let affinity: Affinity
    let xOffset: CGFloat? // in text container coordinates
    let markedRange: Range<Buffer.Index>?

    init(range: Range<Buffer.Index>, affinity: Affinity, xOffset: CGFloat?, markedRange: Range<Buffer.Index>?) {
        self.range = range
        self.affinity = affinity
        self.xOffset = xOffset
        self.markedRange = markedRange
    }

    init(caretAt index: Buffer.Index, affinity: Affinity, xOffset: CGFloat? = nil, markedRange: Range<Buffer.Index>? = nil) {
        self.init(range: index..<index, affinity: affinity, xOffset: xOffset, markedRange: markedRange)
    }

    init(anchor: Buffer.Index, head: Buffer.Index, xOffset: CGFloat? = nil, markedRange: Range<Buffer.Index>? = nil) {
        assert(anchor != head, "anchor and head must be different")

        let i = min(anchor, head)
        let j = max(anchor, head)
        let affinity: Affinity = anchor < head ? .downstream : .upstream

        self.init(range: i..<j, affinity: affinity, xOffset: xOffset, markedRange: markedRange)
    }

    var isCaret: Bool {
        head == anchor
    }

    var isRange: Bool {
        !isCaret
    }

    var caret: Buffer.Index? {
        isCaret ? head : nil
    }

    var anchor: Buffer.Index {
        if affinity == .upstream {
            range.upperBound
        } else {
            range.lowerBound
        }
    }

    var head: Buffer.Index {
        if affinity == .upstream {
            range.lowerBound
        } else {
            range.upperBound
        }
    }

    var lowerBound: Buffer.Index {
        range.lowerBound
    }

    var upperBound: Buffer.Index {
        range.upperBound
    }

    var unmarked: Selection {
        Selection(range: range, affinity: affinity, xOffset: xOffset, markedRange: nil)
    }
}

extension Affinity: InitializableFromAffinity {
    init(_ affinity: StandardKeyBindingResponder.Affinity) {
        switch affinity {
        case .upstream: self = .upstream
        case .downstream: self = .downstream
        }
    }
}

extension Selection: NavigableSelection {
    init(caretAt index: Buffer.Index, affinity: Affinity, xOffset: CGFloat?) {
        self.init(caretAt: index, affinity: affinity, xOffset: xOffset, markedRange: nil)
    }

    init(anchor: Buffer.Index, head: Buffer.Index, xOffset: CGFloat?) {
        self.init(anchor: anchor, head: head, xOffset: xOffset, markedRange: nil)
    }
}
