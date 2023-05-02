//
//  TextView+Layout.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import AppKit

extension TextView: LayoutManagerDelegate, NSViewLayerContentScaleDelegate {
    override func layout() {
        guard let layer else {
            return
        }

        if textLayer.superlayer == nil {
            textLayer.anchorPoint = .zero
            textLayer.bounds = layer.bounds
            layer.addSublayer(textLayer)
        }

        layoutManager.layoutViewport()
    }

    func viewportBounds(for layoutManager: LayoutManager) -> CGRect {
        var viewportBounds: CGRect
        if preparedContentRect.intersects(visibleRect) {
            viewportBounds = preparedContentRect.union(visibleRect)
        } else {
            viewportBounds = visibleRect
        }

        viewportBounds.size.width = bounds.width

        return viewportBounds
    }

    func layoutManagerWillLayout(_ layoutManager: LayoutManager) {
        textLayer.sublayers = nil
    }

    func layoutManager(_ layoutManager: LayoutManager, configureRenderingSurfaceFor layoutFragment: LayoutFragment) {

        let l = TextLayer(layoutFragment: layoutFragment)
        l.contentsScale = window?.backingScaleFactor ?? 1.0
        textLayer.addSublayer(l)
    }

    func layoutManagerDidLayout(_ layoutManager: LayoutManager) {
    }

    func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        true
    }
}
