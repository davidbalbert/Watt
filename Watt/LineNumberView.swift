//
//  LineNumberView.swift
//  Watt
//
//  Created by David Albert on 5/12/23.
//

import Cocoa

class LineNumberView: NSView {
    override func updateLayer() {
        layer?.backgroundColor = NSColor.blue.cgColor
    }
}
