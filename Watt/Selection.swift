//
//  Selection.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import Foundation

extension LayoutManager {
    struct Selection {
        enum Affinity {
            case upstream
            case downstream
        }

        var head: Location
        var anchor: Location
        var affinity: Affinity

        init(head: Location, anchor: Location? = nil, affinity: Affinity? = nil) {
            self.head = head
            self.anchor = anchor ?? head
            self.affinity = affinity ?? .downstream
        }

        var range: Range<Location> {
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
}
