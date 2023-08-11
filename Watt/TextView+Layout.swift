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
        let inset = computedTextContainerInset
        let width = max(0, frame.width - inset.left - inset.right)

        if layoutManager.textContainer.size.width != width {
            layoutManager.textContainer.size = CGSize(width: width, height: 0)

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
    func updateComputedTextContainerInset() {
        let userInset = textContainerInset

        if lineNumberView.superview != nil {
            computedTextContainerInset = NSEdgeInsets(
                top: userInset.top,
                left: userInset.left + lineNumberView.frame.width,
                bottom: userInset.bottom,
                right: userInset.right
            )
        } else {
            computedTextContainerInset = userInset
        }
    }

    var scrollOffset: CGPoint {
        guard let scrollView else {
            return .zero
        }

        return scrollView.contentView.bounds.origin
    }

    func convertFromTextContainer(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + computedTextContainerInset.left, y: point.y + computedTextContainerInset.top)
    }

    func convertToTextContainer(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - computedTextContainerInset.left, y: point.y - computedTextContainerInset.top)
    }
}


extension TextView: LayoutManagerDelegate {
    func visibleRect(for layoutManager: LayoutManager) -> CGRect {
        var r = visibleRect
        r.size.width = textContainer.width

        return r
    }

    func viewportBounds(for layoutManager: LayoutManager) -> CGRect {
        var bounds: CGRect
        if preparedContentRect.intersects(visibleRect) {
            bounds = preparedContentRect.union(visibleRect)
        } else {
            bounds = visibleRect
        }

        bounds.size.width = textContainer.width

        return bounds
    }

    func setNeedsLayout(for layoutManager: LayoutManager) {
        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }

    func layoutManager(_ layoutManager: LayoutManager, adjustScrollOffsetBy adjustment: CGSize) {
        let current = scrollOffset
        scroll(CGPoint(x: current.x + adjustment.width, y: current.y + adjustment.height))
    }

    // MARK: - Text layout

    // TODO: once we're caching breaks and/or lines in the layout manager, switch from
    // delegate methods (willLayout, configureRenderingSurface, didLayout) to a single
    // callback passed into layout text that takes a Line, creates a layer, and inserts
    // the layer as appropriate.
    //
    // The reason to do it with a callback is we'd like to do things like calculate the
    // scroll offset adjustments in TextView rather than LayoutManager, and if we wanted
    // to do that with the current delegate-based approach, we'd need to introduce a
    // property. If we did it with a closure, we could just use a local variable and
    // everything could stay put.
    func layoutTextLayer() {
        textLayer.sublayers = nil

        layoutManager.layoutText { line in
            let l = textLayerCache[line.id] ?? makeLayer(forLine: line)
            l.bounds = line.typographicBounds
            l.position = convertFromTextContainer(line.origin)
            textLayerCache[line.id] = l

            textLayer.addSublayer(l)
        }

        updateFrameHeightIfNeeded()
    }

    func makeLayer(forLine line: Line) -> CALayer {
        let l = LineLayer(line: line)
        l.anchorPoint = .zero
        l.needsDisplayOnBoundsChange = true
        l.delegate = self // NSViewLayerContentScaleDelegate
        l.contentsScale = window?.backingScaleFactor ?? 1.0

        return l
    }

    // MARK: - Selection layout

    func layoutSelectionLayer() {
        selectionLayer.sublayers = nil

        layoutManager.layoutSelections { rect in
            let l = selectionLayerCache[rect] ?? makeLayer(forSelectionRect: rect)
            selectionLayerCache[rect] = l

            selectionLayer.addSublayer(l)
        }
    }

    func makeLayer(forSelectionRect rect: CGRect) -> CALayer {
        let l = SelectionLayer()
        l.anchorPoint = .zero
        l.delegate = self // NSViewLayerContentScaleDelegate
        l.selectionDelegate = self
        l.needsDisplayOnBoundsChange = true
        l.contentsScale = window?.backingScaleFactor ?? 1.0
        l.bounds = CGRect(origin: .zero, size: rect.size)
        l.position = convertFromTextContainer(rect.origin)

        return l
    }

    // MARK: - Insertion point layout

    func layoutInsertionPointLayer() {
        insertionPointLayer.sublayers = nil

        layoutManager.layoutInsertionPoints { rect in
            let l = insertionPointLayerCache[rect] ?? makeLayer(forInsertionPointRect: rect)
            selectionLayerCache[rect] = l

            insertionPointLayer.addSublayer(l)
        }
    }

    func makeLayer(forInsertionPointRect rect: CGRect) -> CALayer {
        let l = InsertionPointLayer()
        l.anchorPoint = .zero
        l.delegate = self // NSViewLayerContentScaleDelegate
        l.needsDisplayOnBoundsChange = true
        l.contentsScale = window?.backingScaleFactor ?? 1.0
        l.bounds = CGRect(origin: .zero, size: rect.size)
        l.position = convertFromTextContainer(rect.origin)

        return l
    }
}
