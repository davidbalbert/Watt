//
//  LayoutFragmentLayerRenderer.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import Cocoa

class LayoutFragmentRenderer<ContentManager>: NSObject, CALayerDelegate, NSViewLayerContentScaleDelegate where ContentManager: TextContentManager {
    typealias LayoutFragment = LayoutManager<ContentManager>.LayoutFragment

    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        return NSNull()
    }

    func draw(_ layer: CALayer, in ctx: CGContext) {
        guard let layoutFragment = layer.value(forKey: CALayer.layoutFragmentKey) as? LayoutFragment else {
            return
        }

        layoutFragment.draw(at: .zero, in: ctx)
    }

    func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        true
    }
}
