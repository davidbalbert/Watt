//
//  TextView+Layout.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import AppKit

extension TextView {
    override func layout() {
        guard let layer else {
            return
        }

        if selectionLayer.superlayer == nil {
            selectionLayer.anchorPoint = .zero
            selectionLayer.bounds = layer.bounds
            selectionLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer.addSublayer(selectionLayer)
        }

        if textLayer.superlayer == nil {
            textLayer.anchorPoint = .zero
            textLayer.bounds = layer.bounds
            textLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer.addSublayer(textLayer)
        }

        super.layout()
    }

    var scrollView: NSScrollView? {
        if let enclosingScrollView, enclosingScrollView.documentView == self {
            return enclosingScrollView
        }

        return nil
    }

    override func prepareContent(in rect: NSRect) {
        super.prepareContent(in: rect)
        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        updateTextContainerSizeIfNecessary()
    }

    func updateTextContainerSizeIfNecessary() {
        let width = max(0, frame.width - textContainerInset.width)

        if textContainer.size.width != width {
            textContainer.size = CGSize(width: width, height: 0)
        }
    }

    func convertToTextContainer(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - textContainerInset.width, y: point.y - textContainerInset.height)
    }
}

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
        guard let scrollView else {
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
