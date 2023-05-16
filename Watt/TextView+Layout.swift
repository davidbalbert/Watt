//
//  TextView+Layout.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import AppKit

extension TextView: LayoutManagerDelegate {
    func viewportBounds(for layoutManager: LayoutManager<ContentManager>) -> CGRect {
        var viewportBounds: CGRect
        if preparedContentRect.intersects(visibleRect) {
            viewportBounds = preparedContentRect.union(visibleRect)
        } else {
            viewportBounds = visibleRect
        }

        viewportBounds.size.width = bounds.width

        return viewportBounds
    }

    func layoutManagerWillLayout(_ layoutManager: LayoutManager<ContentManager>) {
        textLayer.sublayers = nil
        lineNumberView.beginUpdates()
    }

    func layoutManager(_ layoutManager: LayoutManager<ContentManager>, configureRenderingSurfaceFor layoutFragment: LayoutFragment) {
        let l = fragmentLayerMap[layoutFragment.id] ?? TextLayer(layoutFragment: layoutFragment)

        l.contentsScale = window?.backingScaleFactor ?? 1.0
        l.needsDisplayOnBoundsChange = true
        l.anchorPoint = .zero
        l.bounds = layoutFragment.typographicBounds
        l.position = CGPoint(x: layoutFragment.position.x + textContainerInset.width, y: layoutFragment.position.y)

        fragmentLayerMap[layoutFragment.id] = l

        textLayer.addSublayer(l)

        guard let frag = layoutFragment.lineFragments.first else {
            return
        }

        lineNumberView.addLineNumber(layoutFragment.lineNumber, at: layoutFragment.position, withLineHeight: frag.typographicBounds.height)
    }

    func layoutManagerDidLayout(_ layoutManager: LayoutManager<ContentManager>) {
        updateFrameHeightIfNeeded()
        lineNumberView.endUpdates()
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
