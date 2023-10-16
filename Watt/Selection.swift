//
//  Selection.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import Foundation

struct Selection {
    enum Affinity {
        case upstream
        case downstream
    }

    let head: Rope.Index
    let anchor: Rope.Index
    let affinity: Affinity
    let xOffset: CGFloat
    let markedRange: Range<Rope.Index>?

    init(head: Buffer.Index, anchor: Buffer.Index? = nil, affinity: Affinity, xOffset: CGFloat, markedRange: Range<Rope.Index>? = nil) {
        self.head = head
        self.anchor = anchor ?? head
        self.affinity = affinity
        self.xOffset = xOffset
        self.markedRange = markedRange
    }

    var range: Range<Rope.Index> {
        if head < anchor {
            return head..<anchor
        } else {
            return anchor..<head
        }
    }

    var lowerBound: Rope.Index {
        range.lowerBound
    }

    var upperBound: Rope.Index {
        range.upperBound
    }

    var isEmpty: Bool {
        head == anchor
    }

    var unmarked: Selection {
        Selection(head: head, anchor: anchor, affinity: affinity, xOffset: xOffset, markedRange: markedRange)
    }
}
