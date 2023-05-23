//
//  InsertionPointLayer.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

class InsertionPointLayer: CALayer {
    override func display() {
        backgroundColor = NSColor.black.cgColor
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
