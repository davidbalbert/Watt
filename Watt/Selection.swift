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

    var head: Rope.Index {
        didSet {
            if head < anchor {
                affinity = .upstream
            } else if anchor < head {
                affinity = .downstream
            }
        }
    }

    var anchor: Rope.Index
    var affinity: Affinity
    var markedRange: Range<Rope.Index>?
    var xOffset: CGFloat

    init(head: Buffer.Index, anchor: Buffer.Index? = nil, affinity: Affinity = .downstream, xOffset: CGFloat = 0) {
        self.head = head
        self.anchor = anchor ?? head
        self.affinity = affinity
        self.xOffset = xOffset
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
}
