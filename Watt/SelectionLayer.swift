//
//  SelectionLayer.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

protocol SelectionLayerDelegate: AnyObject {
    func selectedTextBackgroundColor(for selectionLayer: SelectionLayer) -> NSColor
    func effectiveAppearance(for selectionLayer: SelectionLayer) -> NSAppearance
}

class SelectionLayer: CALayer {
    weak var selectionDelegate: SelectionLayerDelegate?

    override func display() {
        guard let selectionDelegate else {
            return
        }

        selectionDelegate.effectiveAppearance(for: self).performAsCurrentDrawingAppearance {
            backgroundColor = selectionDelegate.selectedTextBackgroundColor(for: self).cgColor
        }
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
