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

    var head: String.Index {
        didSet {
            if head < anchor {
                affinity = .upstream
            } else if anchor < head {
                affinity = .downstream
            }
        }
    }

    var anchor: String.Index
    var affinity: Affinity

    init(head: String.Index, anchor: String.Index? = nil, affinity: Affinity? = nil) {
        self.head = head
        self.anchor = anchor ?? head
        self.affinity = affinity ?? .downstream
    }

    var range: Range<String.Index> {
        if head < anchor {
            return head..<anchor
        } else {
            return anchor..<head
        }
    }

    var isEmpty: Bool {
        head == anchor
    }
}
