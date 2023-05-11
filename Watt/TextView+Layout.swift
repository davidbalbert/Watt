//
//  TextView+Layout.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import AppKit

extension TextView: LayoutManagerDelegate {
    func viewportBounds(for layoutManager: LayoutManager<Storage>) -> CGRect {
        var viewportBounds: CGRect
        if preparedContentRect.intersects(visibleRect) {
            viewportBounds = preparedContentRect.union(visibleRect)
        } else {
            viewportBounds = visibleRect
        }

        viewportBounds.size.width = bounds.width

        return viewportBounds
    }

    func layoutManagerWillLayout(_ layoutManager: LayoutManager<Storage>) {
        textLayer.sublayers = nil
    }

    func layoutManager(_ layoutManager: LayoutManager<Storage>, configureRenderingSurfaceFor layoutFragment: LayoutFragment<Storage>) {
        let l = TextLayer(layoutFragment: layoutFragment)
        l.contentsScale = window?.backingScaleFactor ?? 1.0
        textLayer.addSublayer(l)
    }

    func layoutManagerDidLayout(_ layoutManager: LayoutManager<Storage>) {
        updateFrameHeightIfNeeded()
    }

    func updateFrameHeightIfNeeded() {
        guard let scrollView = enclosingScrollView else {
            return
        }

        let contentHeight = layoutManager.documentHeight
        let viewportHeight = scrollView.contentSize.height
        let newHeight = round(max(contentHeight, viewportHeight))

        let currentHeight = frame.height

        if abs(currentHeight - newHeight) > 1e-10 {
            setFrameSize(CGSize(width: frame.width, height: newHeight))
        }
    }
}
