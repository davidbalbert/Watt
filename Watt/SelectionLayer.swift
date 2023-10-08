//
//  SelectionLayer.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

protocol SelectionLayerDelegate: AnyObject {
    func selectedTextBackgroundColor(for selectionLayer: SelectionLayer) -> NSColor
}

class SelectionLayer: CALayer {
    weak var selectionDelegate: SelectionLayerDelegate?

    override func display() {
        backgroundColor = selectionDelegate?.selectedTextBackgroundColor(for: self).cgColor ?? NSColor.selectedTextBackgroundColor.cgColor
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
