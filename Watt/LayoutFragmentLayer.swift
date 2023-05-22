//
//  LayoutFragmentLayer.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

class LayoutFragmentLayer: CALayer {
    var layoutFragment: LayoutFragment

    init(layoutFragment: LayoutFragment) {
        self.layoutFragment = layoutFragment
        super.init()
    }

    override init(layer: Any) {
        let layer = layer as! LayoutFragmentLayer
        self.layoutFragment = layer.layoutFragment
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(in ctx: CGContext) {
        layoutFragment.draw(at: .zero, in: ctx)
    }

    override func action(forKey event: String) -> CAAction? {
        NSNull()
    }
}
