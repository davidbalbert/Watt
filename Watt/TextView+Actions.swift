//
//  TextView+Actions.swift
//  Watt
//
//  Created by David Albert on 5/24/23.
//

import Cocoa

extension TextView {
    override func selectAll(_ sender: Any?) {
        layoutManager.selection = Selection(head: buffer.documentRange.upperBound, anchor: buffer.documentRange.lowerBound, affinity: .downstream)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }
}
