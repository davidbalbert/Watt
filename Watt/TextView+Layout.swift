//
//  TextView+Layout.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

extension TextView: CALayerDelegate, NSViewLayerContentScaleDelegate {
    override func layout() {
        // If we need to call setNeedsLayout on our subviews, do it here,
        // before calling super.layout()

        super.layout()

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

        if insertionPointLayer.superlayer == nil {
            insertionPointLayer.bounds = layer.bounds
            layer.addSublayer(insertionPointLayer)
        }
    }

    func layoutSublayers(of layer: CALayer) {
        switch layer {
        case textLayer:
            layoutTextLayer()
        case selectionLayer:
            layoutSelectionLayer()
        case insertionPointLayer:
            layoutInsertionPointLayer()
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

        selectionLayer.setNeedsLayout()
        textLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateTextContainerSizeIfNeeded()
    }

    func updateTextContainerSizeIfNeeded() {
        // TODO: this is called from setFrameSize, make sure
        // this is called before layout(). I'm 99% sure it
        // will be.

        let inset = calculateTextContainerInset()
        let width = max(0, frame.width - inset.left - inset.right)

        if layoutManager.textContainer.size.width != width {
            layoutManager.textContainer.size = CGSize(width: width, height: 0)
            layoutManager.textContainerInset = inset

            // This isn't needed when this function is called from
            // setFrameSize, but it is needed when the line number
            // view is added, removed, or resized due to the number
            // of lines in the document changing.
            //
            // In the former case, AppKit will resize the view's
            // layer, which will trigger the resizing of these layers
            // due to their autoresizing masks.
            //
            // In the latter case, because the line number view floats
            // above the text view, the text view's frame size doesn't
            // change when the line number view's size changes, but we
            // do need to re-layout our text.
            selectionLayer.setNeedsLayout()
            textLayer.setNeedsLayout()
            insertionPointLayer.setNeedsLayout()
        }
    }

    func updateFrameHeightIfNeeded() {
        guard let scrollView else {
            return
        }

        let currentHeight = frame.height
        let newHeight = round(max(scrollView.contentSize.height, layoutManager.contentHeight))

        if abs(currentHeight - newHeight) > 1e-10 {
            setFrameSize(CGSize(width: frame.width, height: newHeight))
        }
    }

    // Takes the user specified textContainerInset and combines
    // it with the line number view's dimensions.
    func calculateTextContainerInset() -> NSEdgeInsets {
        let userInset = textContainerInset

        if lineNumberView.superview != nil {
            return NSEdgeInsets(
                top: userInset.top,
                left: userInset.left + lineNumberView.frame.width,
                bottom: userInset.bottom,
                right: userInset.right
            )
        } else {
            return userInset
        }
    }
}


extension TextView: LayoutManagerDelegate {
    func viewportBounds(for layoutManager: LayoutManager) -> CGRect {
        var bounds: CGRect
        if preparedContentRect.intersects(visibleRect) {
            bounds = preparedContentRect.union(visibleRect)
        } else {
            bounds = visibleRect
        }

        bounds.size.width = bounds.width

        return bounds
    }

    // MARK: - Text layout

    func layoutTextLayer() {
        layoutManager.layoutText()
    }

    func layoutManagerWillLayoutText(_ layoutManager: LayoutManager) {
        textLayer.sublayers = nil
    }

    func layoutManager(_ layoutManager: LayoutManager, createTextLayerFor line: Line) -> LineLayer {
        let l = LineLayer(line: line)
        l.anchorPoint = .zero
        l.needsDisplayOnBoundsChange = true
        l.delegate = self // NSViewLayerContentScaleDelegate
        l.contentsScale = window?.backingScaleFactor ?? 1.0

        return l
    }

    func layoutManager(_ layoutManager: LayoutManager, insertTextLayer layer: LineLayer) {
        layer.bounds = layer.line.typographicBounds
        layer.position = layoutManager.convertFromTextContainer(layer.line.position)

        textLayer.addSublayer(layer)
    }

    func layoutManagerDidLayoutText(_ layoutManager: LayoutManager) {
        updateFrameHeightIfNeeded()
    }

    // MARK: - Selection layout

    func layoutSelectionLayer() {
        layoutManager.layoutSelections()
    }
    
    func layoutManagerWillLayoutSelections(_ layoutManager: LayoutManager) {
        selectionLayer.sublayers = nil
    }

    func layoutManager(_ layoutManager: LayoutManager, createSelectionLayerFor rect: CGRect) -> CALayer {
        let l = SelectionLayer(textView: self)
        l.anchorPoint = .zero
        l.delegate = self // NSViewLayerContentScaleDelegate
        l.needsDisplayOnBoundsChange = true
        l.contentsScale = window?.backingScaleFactor ??  1.0

        return l
    }

    func layoutManager(_ layoutManager: LayoutManager, insertSelectionLayer layer: CALayer) {
        selectionLayer.addSublayer(layer)
    }


    func layoutManagerDidLayoutSelections(_ layoutManager: LayoutManager) {
        // no-op
    }

//    func layoutSelectionLayer() {
//        selectionLayer.sublayers = nil
//
//        guard let selection else {
//            return
//        }
//
//        if selection.isEmpty {
//            return
//        }
//
//        guard let viewportRange = layoutManager.viewportRange else {
//            return
//        }
//
//        let rangeInViewport = selection.range.clamped(to: viewportRange)
//
//        if rangeInViewport.isEmpty {
//            return
//        }
//
//        layoutManager.enumerateTextSegments(in: rangeInViewport, type: .selection) { _, frame in
//            let l = selectionLayerCache[frame] ?? makeSelectionLayer(for: frame)
//
//            let position = convertFromTextContainer(frame.origin)
//            l.position = position
//            l.bounds = CGRect(origin: .zero, size: frame.size)
//
//            selectionLayerCache[frame] = l
//            selectionLayer.addSublayer(l)
//
//            return true
//        }
//    }
//
//    func makeSelectionLayer(for frame: CGRect) -> CALayer {
//        let l = SelectionLayer(textView: self)
//        l.anchorPoint = .zero
//        l.delegate = self // NSViewLayerContentScaleDelegate
//        l.needsDisplayOnBoundsChange = true
//        l.contentsScale = window?.backingScaleFactor ??  1.0
//
//        return l
//    }

    // MARK: - Insertion point layout

    func layoutInsertionPointLayer() {
        layoutManager.layoutInsertionPoints()
    }

    func layoutManagerWillLayoutInsertionPoints(_ layoutManager: LayoutManager) {
        insertionPointLayer.sublayers = nil
    }

    func layoutManager(_ layoutManager: LayoutManager, insertInsertionPointLayer layer: CALayer) {
        insertionPointLayer.addSublayer(layer)
    }

    func layoutManagerDidLayoutInsertionPoints(_ layoutManager: LayoutManager) {
        // no-op
    }

//    func layoutInsertionPointLayer() {
//        insertionPointLayer.sublayers = nil
//
//        guard let selection else {
//            return
//        }
//
//        guard selection.isEmpty else {
//            return
//        }
//
//        guard let viewportRange = layoutManager.viewportRange else {
//            return
//        }
//
//        guard viewportRange.contains(selection.range.lowerBound) || viewportRange.upperBound == selection.range.upperBound else {
//            return
//        }
//
//        layoutManager.enumerateCaretRectsInLineFragment(at: selection.range.lowerBound, affinity: selection.affinity) { [weak self] caretRect, location, leadingEdge in
//            guard let self else {
//                return false
//            }
//
//            let next = buffer.location(location, offsetBy: 1)
//
//            let downstreamMatch = location == selection.range.lowerBound && leadingEdge && selection.affinity == .downstream
//            let upstreamMatch = next == selection.range.lowerBound && !leadingEdge && selection.affinity == .upstream
//
//            guard downstreamMatch || upstreamMatch else {
//                return true
//            }
//
//            let l = insertionPointLayerCache[caretRect] ?? makeInsertionPointLayer(for: caretRect)
//            l.position = convertFromTextContainer(caretRect.origin)
//            l.bounds = CGRect(origin: .zero, size: caretRect.size)
//
//            insertionPointLayerCache[caretRect] = l
//            insertionPointLayer.addSublayer(l)
//
//            return false
//        }
//    }
//
//    func makeInsertionPointLayer(for rect: CGRect) -> CALayer {
//        let l = InsertionPointLayer()
//        l.anchorPoint = .zero
//        l.delegate = self // NSViewLayerContentScaleDelegate
//        l.needsDisplayOnBoundsChange = true
//        l.contentsScale = window?.backingScaleFactor ??  1.0
//
//        return l
//    }
}
