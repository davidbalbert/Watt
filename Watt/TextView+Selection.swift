//
//  TextView+Selection.swift
//  Watt
//
//  Created by David Albert on 5/19/23.
//

import Cocoa

extension TextView {
    func startSelection(at point: CGPoint) {
        guard let location = layoutManager.location(for: point) else {
            return
        }

        layoutManager.selection = Selection(head: location)
        selectionLayer.needsLayout()
    }

    func extendSelection(to point: CGPoint) {
        guard let location = layoutManager.location(for: point) else {
            return
        }

        layoutManager.selection?.head = location
        selectionLayer.needsLayout()
    }
}
