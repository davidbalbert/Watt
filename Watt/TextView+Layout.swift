//
//  TextView+Layout.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import AppKit

extension TextView: TextLayerLayoutDelegate {
    func viewportBounds(for textLayerLayout: TextLayerLayout) -> CGRect {
        var viewportBounds: CGRect
        if preparedContentRect.intersects(visibleRect) {
            viewportBounds = preparedContentRect.union(visibleRect)
        } else {
            viewportBounds = visibleRect
        }

        viewportBounds.size.width = bounds.width

        return viewportBounds
    }

    func textLayerLayoutWillLayout(_ textLayerLayout: TextLayerLayout) {
        lineNumberView.beginUpdates()
    }

    func textLayerLayout(_ textLayerLayout: TextLayerLayout, didLayout layoutFragment: LayoutFragment) {

        guard let frag = layoutFragment.lineFragments.first else {
            return
        }

        lineNumberView.addLineNumber(layoutFragment.lineNumber, at: layoutFragment.position, withLineHeight: frag.typographicBounds.height)
    }

    func textLayerLayoutDidFinishLayout(_ textLayerLayout: TextLayerLayout) {
        updateFrameHeightIfNeeded()
        lineNumberView.endUpdates()
    }

    func backingScaleFactor(for textLayerLayout: TextLayerLayout) -> CGFloat {
        window?.backingScaleFactor ?? 1.0
    }

    func textLayerLayout(_ textLayerLayout: TextLayerLayout, insetFor layoutFragment: LayoutFragment) -> CGSize {
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

extension TextView: SelectionLayerLayoutDelegate {
    func backingScaleFactor(for selectionLayerLayout: SelectionLayerLayout) -> CGFloat {
        window?.backingScaleFactor ?? 1.0
    }

    func textContainerInsets(for selectionLayerLayout: SelectionLayerLayout) -> CGSize {
        textContainerInset
    }
}
