//
//  SelectionLayer.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

protocol SelectionLayerDelegate: CALayerDelegate {
    func selectedTextBackgroundColor(for selectionLayer: SelectionLayer) -> NSColor
    func effectiveAppearance(for selectionLayer: SelectionLayer) -> NSAppearance
}

class SelectionLayer: CALayer {
    override func display() {
        guard let delegate = delegate as? SelectionLayerDelegate else {
            return
        }

        delegate.effectiveAppearance(for: self).performAsCurrentDrawingAppearance {
            backgroundColor = delegate.selectedTextBackgroundColor(for: self).cgColor
        }
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
