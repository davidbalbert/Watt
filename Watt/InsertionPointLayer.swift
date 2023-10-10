//
//  InsertionPointLayer.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

protocol InsertionPointLayerDelegate: CALayerDelegate {
    func insertionPointColor(for insertionPointLayer: InsertionPointLayer) -> NSColor
    func effectiveAppearance(for insertionPointLayer: InsertionPointLayer) -> NSAppearance
}

class InsertionPointLayer: CALayer {
    override func display() {
        guard let delegate = delegate as? InsertionPointLayerDelegate else {
            return
        }

        delegate.effectiveAppearance(for: self).performAsCurrentDrawingAppearance {
            backgroundColor = delegate.insertionPointColor(for: self).cgColor
        }
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
