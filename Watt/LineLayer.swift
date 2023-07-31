//
//  LineLayer.swift
//  Watt
//
//  Created by David Albert on 7/19/23.
//

import Cocoa

class LineLayer: CALayer {
    var line: Line

    init(line: Line) {
        self.line = line
        super.init()
    }

    override init(layer: Any) {
        let layer = layer as! LineLayer
        self.line = layer.line
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(in ctx: CGContext) {
        line.draw(at: .zero, in: ctx)
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
