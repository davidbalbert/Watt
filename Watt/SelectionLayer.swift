//
//  SelectionLayer.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

class SelectionLayer: CALayer {
    weak var textView: TextView?

    init(textView: TextView) {
        self.textView = textView
        super.init()
    }

    override init(layer: Any) {
        let layer = layer as! SelectionLayer
        self.textView = layer.textView
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func display() {
        backgroundColor = NSColor.selectedTextBackgroundColor.cgColor
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
