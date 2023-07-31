//
//  SelectionLayer.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

class SelectionLayer: CALayer {
    override func display() {
        backgroundColor = NSColor.selectedTextBackgroundColor.cgColor
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
