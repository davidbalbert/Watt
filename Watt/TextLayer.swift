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
        bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
//        bounds = layoutFragment.bounds
//        bounds.size.width += 50
//        bounds.size.height += 50
        borderColor = NSColor.purple.cgColor
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
