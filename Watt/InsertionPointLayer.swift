//
//  InsertionPointLayer.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

protocol InsertionPointLayerDelegate: AnyObject {
    func insertionPointColor(for insertionPointLayer: InsertionPointLayer) -> NSColor
    func effectiveAppearance(for insertionPointLayer: InsertionPointLayer) -> NSAppearance
}

class InsertionPointLayer: CALayer {
    weak var insertionPointDelegate: InsertionPointLayerDelegate?

    override func display() {
        guard let insertionPointDelegate else {
            return
        }

        insertionPointDelegate.effectiveAppearance(for: self).performAsCurrentDrawingAppearance {
            backgroundColor = insertionPointDelegate.insertionPointColor(for: self).cgColor
        }
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
