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

extension Affinity: InitializableFromAffinity {
    init(_ affinity: StandardKeyBindingResponder.Affinity) {
        switch affinity {
        case .upstream: self = .upstream
        case .downstream: self = .downstream
        }
    }
}

enum Granularity {
    case character
    case word
    case line
    case paragraph
}

extension Granularity: InitializableFromGranularity {
    init(_ granularity: StandardKeyBindingResponder.Granularity) {
        switch granularity {
        case .character: self = .character
        case .word: self = .word
        case .line: self = .line
        case .paragraph: self = .paragraph
        }
    }
}

struct Selection {
    let range: Range<Buffer.Index>
    // For caret, determines which side of a line wrap the caret is on.
    // For range, determins which the end is head, and which end is the anchor.
    let affinity: Affinity
    let granularity: Granularity
    let xOffset: CGFloat? // in text container coordinates
    let markedRange: Range<Buffer.Index>?

    init(range: Range<Buffer.Index>, affinity: Affinity, granularity: Granularity, xOffset: CGFloat?, markedRange: Range<Buffer.Index>?) {
        self.range = range
        self.affinity = affinity
        self.granularity = granularity
        self.xOffset = xOffset
        self.markedRange = markedRange
    }

    init(caretAt index: Buffer.Index, affinity: Affinity, granularity: Granularity, xOffset: CGFloat? = nil, markedRange: Range<Buffer.Index>? = nil) {
        self.init(range: index..<index, affinity: affinity, granularity: granularity, xOffset: xOffset, markedRange: markedRange)
    }

    init(anchor: Buffer.Index, head: Buffer.Index, granularity: Granularity, xOffset: CGFloat? = nil, markedRange: Range<Buffer.Index>? = nil) {
        assert(anchor != head, "anchor and head must be different")

        let i = min(anchor, head)
        let j = max(anchor, head)
        let affinity: Affinity = anchor < head ? .downstream : .upstream

        self.init(range: i..<j, affinity: affinity, granularity: granularity, xOffset: xOffset, markedRange: markedRange)
    }

    init(atStartOf buffer: Buffer) {
        let affinity: Selection.Affinity = buffer.isEmpty ? .upstream : .downstream
        self.init(caretAt: buffer.startIndex, affinity: affinity, granularity: .character, xOffset: nil)
    }

    var isCaret: Bool {
        head == anchor
    }

    var isRange: Bool {
        !isCaret
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
        Selection(range: range, affinity: affinity, granularity: granularity, xOffset: xOffset, markedRange: nil)
    }
}

extension Selection: NavigableSelection {
    init(caretAt index: Buffer.Index, affinity: Affinity, granularity: Granularity, xOffset: CGFloat?) {
        self.init(caretAt: index, affinity: affinity, granularity: granularity, xOffset: xOffset, markedRange: nil)
    }

    init(anchor: Buffer.Index, head: Buffer.Index, granularity: Granularity, xOffset: CGFloat?) {
        self.init(anchor: anchor, head: head, granularity: granularity, xOffset: xOffset, markedRange: nil)
    }
}
