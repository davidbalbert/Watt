//
//  TextView+Layout.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import AppKit

extension TextView: TextLayerLayoutDelegate {
    func viewportBounds(for textLayerLayout: TextLayerLayout<ContentManager>) -> CGRect {
        var viewportBounds: CGRect
        if preparedContentRect.intersects(visibleRect) {
            viewportBounds = preparedContentRect.union(visibleRect)
        } else {
            viewportBounds = visibleRect
        }

        viewportBounds.size.width = bounds.width

        return viewportBounds
    }

    func textLayerLayoutWillLayout(_ textLayerLayout: TextLayerLayout<ContentManager>) {
        lineNumberView.beginUpdates()
    }

    func textLayerLayout(_ textLayerLayout: TextLayerLayout<ContentManager>, didLayout layoutFragment: LayoutManager<ContentManager>.LayoutFragment) {

        guard let frag = layoutFragment.lineFragments.first else {
            return
        }

        lineNumberView.addLineNumber(layoutFragment.lineNumber, at: layoutFragment.position, withLineHeight: frag.typographicBounds.height)
    }

    func textLayerLayoutDidFinishLayout(_ textLayerLayout: TextLayerLayout<ContentManager>) {
        updateFrameHeightIfNeeded()
        lineNumberView.endUpdates()
    }

    func backingScaleFactor(for textLayerLayout: TextLayerLayout<ContentManager>) -> CGFloat {
        window?.backingScaleFactor ?? 1.0
    }

    func textLayerLayout(_ textLayerLayout: TextLayerLayout<ContentManager>, insetFor layoutFragment: LayoutManager<ContentManager>.LayoutFragment) -> CGSize {
        textContainerInset
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
