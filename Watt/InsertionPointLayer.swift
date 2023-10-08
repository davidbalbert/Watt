//
//  InsertionPointLayer.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

protocol InsertionPointLayerDelegate: AnyObject {
    func insertionPointColor(for selectionLayer: InsertionPointLayer) -> NSColor
}

class InsertionPointLayer: CALayer {
    weak var insertionPointDelegate: InsertionPointLayerDelegate?

    override func display() {
        backgroundColor = insertionPointDelegate?.insertionPointColor(for: self).cgColor ?? .black
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
