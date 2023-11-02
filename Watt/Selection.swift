//
//  Selection.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import Foundation
import StandardKeyBindingResponder

struct Selection {
    enum Affinity {
        case upstream
        case downstream
    }

    enum Granularity {
        case character
        case word
        case line        
    }

    let range: Range<Buffer.Index>
    // For caret, determines which side of a line wrap the caret is on.
    // For range, determins which the end is head, and which end is the anchor.
    let affinity: Affinity
    let xOffset: CGFloat? // in text container coordinates
    let markedRange: Range<Buffer.Index>?

    init(caretAt index: Buffer.Index, affinity: Affinity, xOffset: CGFloat? = nil, markedRange: Range<Buffer.Index>? = nil) {
        self.init(range: index..<index, affinity: affinity, xOffset: xOffset, markedRange: markedRange)
    }

    // xOffset still needs to be maintained while selecting for a specific special case:
    // If we're moving up from within the first fragment to the beginning of the document
    // or moving down from the within the last fragment to the end of the document, we want
    // to maintain our xOffset so that when we move back in the opposite vertical direction,
    // we move by one line fragment and also jump horizontally to our xOffset
    init(anchor: Buffer.Index, head: Buffer.Index, xOffset: CGFloat? = nil, markedRange: Range<Buffer.Index>? = nil) {
        let i = min(anchor, head)
        let j = max(anchor, head)
        let affinity: Affinity = anchor < head ? .downstream : .upstream

        self.init(range: i..<j, affinity: affinity, xOffset: xOffset, markedRange: markedRange)
    }

    private init(range: Range<Buffer.Index>, affinity: Affinity, xOffset: CGFloat?, markedRange: Range<Buffer.Index>?) {
        self.range = range
        self.affinity = affinity
        self.xOffset = xOffset
        self.markedRange = markedRange
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

extension Selection.Affinity {
    init(_ affinity: SelectionAffinity) {
        switch affinity {
        case .upstream: self = .upstream
        case .downstream: self = .downstream
        }
    }
}

extension SelectionAffinity {
    init(_ affinity: Selection.Affinity) {
        switch affinity {
        case .upstream: self = .upstream
        case .downstream: self = .downstream
        }
    }
}

extension Selection {
    init(_ selection: StandardKeyBindingResponder.Selection<Buffer.Index>) {
        self.range = selection.range
        self.affinity = Affinity(selection.affinity)
        self.xOffset = selection.xOffset
        self.markedRange = nil
    }
}

extension StandardKeyBindingResponder.Selection<Buffer.Index> {
    init(_ selection: Selection) {
        self.init(
            range: selection.range,
            affinity: SelectionAffinity(selection.affinity),
            xOffset: selection.xOffset
        )
    }
}
