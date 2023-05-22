//
//  TextView+Layout.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

extension TextView: CALayerDelegate, NSViewLayerContentScaleDelegate {
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

    func layoutSublayers(of layer: CALayer) {
        switch layer {
        case textLayer:
            layoutTextLayer()
        case selectionLayer:
            layoutSelectionLayer()
        default:
            break
        }
    }

    func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        true
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

    func convertToTextContainer(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - textContainerInset.width, y: point.y - textContainerInset.height)
    }
}

// MARK: - Text layout
extension TextView: LayoutManagerDelegate {
    func layoutTextLayer() {
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
        lineNumberView.beginUpdates()
    }

    func layoutManager(_ layoutManager: LayoutManager, configureRenderingSurfaceFor layoutFragment: LayoutFragment) {

        let l = textLayerCache[layoutFragment.id] ?? makeLayoutFragmentLayer(for: layoutFragment)
        l.bounds = layoutFragment.typographicBounds
        l.position = CGPoint(
            x: layoutFragment.position.x + textContainerInset.width,
            y: layoutFragment.position.y + textContainerInset.height
        )

        textLayerCache[layoutFragment.id] = l

        textLayer.addSublayer(l)

        guard let lineFragment = layoutFragment.lineFragments.first else {
            return
        }

        lineNumberView.addLineNumber(layoutFragment.lineNumber, at: layoutFragment.position, withLineHeight: lineFragment.typographicBounds.height)
    }

    func layoutManagerDidLayout(_ layoutManager: LayoutManager) {
        updateFrameHeightIfNeeded()
        lineNumberView.endUpdates()
    }

    func makeLayoutFragmentLayer(for layoutFragment: LayoutFragment) -> CALayer {
        let l = LayoutFragmentLayer(layoutFragment: layoutFragment)
        l.anchorPoint = .zero
        l.delegate = self // NSViewLayerContentScaleDelegate
        l.needsDisplayOnBoundsChange = true
        l.contentsScale = window?.backingScaleFactor ??  1.0

        return l
    }
}

// MARK: - Selection layout

extension TextView {
    func layoutSelectionLayer() {
        selectionLayer.sublayers = nil

        guard let selection = layoutManager.selection else {
            return
        }

        if selection.isEmpty {
            return
        }

        guard let viewportRange = layoutManager.viewportRange else {
            return
        }

        let rangeInViewport = selection.range.clamped(to: viewportRange)

        if rangeInViewport.isEmpty {
            return
        }

        layoutManager.enumerateSelectionSegments(in: rangeInViewport) { frame in
            let l = selectionLayerCache[frame] ?? makeSelectionLayer(for: frame)

            let padding = textContainer.lineFragmentPadding

            let position = CGPoint(
                x: frame.origin.x + textContainerInset.width + padding,
                y: frame.origin.y + textContainerInset.height
            )

            l.position = position
            l.bounds = CGRect(origin: .zero, size: frame.size)

            selectionLayerCache[frame] = l
            selectionLayer.addSublayer(l)

            return true
        }
    }

    func makeSelectionLayer(for frame: CGRect) -> CALayer {
        let l = SelectionLayer(textView: self)
        l.anchorPoint = .zero
        l.delegate = self // NSViewLayerContentScaleDelegate
        l.needsDisplayOnBoundsChange = true
        l.contentsScale = window?.backingScaleFactor ??  1.0

        return l
    }
}
