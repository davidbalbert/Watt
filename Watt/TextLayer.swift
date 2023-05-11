//
//  TextLayer.swift
//  Watt
//
//  Created by David Albert on 4/30/23.
//

import Cocoa

class TextLayer<Storage>: NonAnimatingLayer where Storage: TextStorage {
    var layoutFragment: LayoutFragment<Storage>

    init(layoutFragment: LayoutFragment<Storage>) {
        self.layoutFragment = layoutFragment
        super.init()
        anchorPoint = .zero
        bounds = layoutFragment.typographicBounds
        position = layoutFragment.position
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

        ctx.saveGState()
        ctx.setStrokeColor(NSColor.systemPurple.cgColor)
        ctx.stroke(layoutFragment.typographicBounds.insetBy(dx: 0.5, dy: 0.5), width: 1)
        ctx.restoreGState()
    }
}
