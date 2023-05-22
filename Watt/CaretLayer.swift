//
//  CaretLayer.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

class CaretLayer: CALayer {
    override func display() {
        backgroundColor = NSColor.black.cgColor
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
