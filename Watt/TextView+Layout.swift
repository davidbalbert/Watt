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
            selectionLayer.bounds = layer.bounds
            layer.addSublayer(selectionLayer)
        }

        if textLayer.superlayer == nil {
            textLayer.bounds = layer.bounds
            layer.addSublayer(textLayer)
        }

        if caretLayer.superlayer == nil {
            caretLayer.bounds = layer.bounds
            layer.addSublayer(caretLayer)
        }

        super.layout()
    }

    func layoutSublayers(of layer: CALayer) {
        switch layer {
        case textLayer:
            layoutTextLayer()
        case selectionLayer:
            layoutSelectionLayer()
        case caretLayer:
            layoutCaretLayer()
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

    func convertFromTextContainer(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + textContainerInset.width, y: point.y + textContainerInset.height)
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

        guard let selection else {
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

            let position = convertFromTextContainer(frame.origin)
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

// MARK: - Caret layout

extension TextView {
    func layoutCaretLayer() {
        caretLayer.sublayers = nil

        guard let selection else {
            return
        }

        guard selection.isEmpty else {
            return
        }

        guard let viewportRange = layoutManager.viewportRange else {
            return
        }

        guard viewportRange.contains(selection.range.lowerBound) else {
            return
        }

        layoutManager.enumerateCaretRectsInLineFragment(at: selection.range.lowerBound, affinity: selection.affinity) { [weak self] caretRect, location, leadingEdge in
            guard let self else {
                return false
            }

            let next = contentManager.location(location, offsetBy: 1)

            let downstreamMatch = location == selection.range.lowerBound && leadingEdge && selection.affinity == .downstream
            let upstreamMatch = next == selection.range.lowerBound && !leadingEdge && selection.affinity == .upstream

            guard downstreamMatch || upstreamMatch else {
                return true
            }

            let l = caretLayerCache[caretRect] ?? makeCaretLayer(for: caretRect)
            l.position = convertFromTextContainer(caretRect.origin)
            l.bounds = CGRect(origin: .zero, size: caretRect.size)

            caretLayerCache[caretRect] = l
            caretLayer.addSublayer(l)

            return false
        }
    }

    func makeCaretLayer(for rect: CGRect) -> CALayer {
        let l = CaretLayer()
        l.anchorPoint = .zero
        l.delegate = self // NSViewLayerContentScaleDelegate
        l.needsDisplayOnBoundsChange = true
        l.contentsScale = window?.backingScaleFactor ??  1.0

        return l
    }
}
