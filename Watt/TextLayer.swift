//
//  TextLayer.swift
//  Watt
//
//  Created by David Albert on 4/30/23.
//

import Cocoa

class TextLayer: NonAnimatingLayer {
    var layoutFragment: LayoutFragment

    init(layoutFragment: LayoutFragment) {
        self.layoutFragment = layoutFragment
        super.init()
        anchorPoint = .zero
        borderColor = NSColor.purple.cgColor
        bounds = layoutFragment.typographicBounds
        borderWidth = 1
        setNeedsDisplay()
    }

    override init(layer: Any) {
        let other = layer as! TextLayer
        self.layoutFragment = other.layoutFragment
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(in ctx: CGContext) {
        layoutFragment.draw(at: .zero, in: ctx)
    }
}
