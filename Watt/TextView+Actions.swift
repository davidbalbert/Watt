//
//  TextView+Actions.swift
//  Watt
//
//  Created by David Albert on 5/24/23.
//

import Cocoa

extension TextView {
    override func selectAll(_ sender: Any?) {
        layoutManager.selection = Selection(head: contentManager.documentRange.upperBound, anchor: contentManager.documentRange.lowerBound, affinity: .downstream)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }
}
