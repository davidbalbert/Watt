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
        let clipviewHeight = scrollView.contentSize.height
        let newHeight = round(max(clipviewHeight, layoutManager.contentHeight))

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

    var textContainerViewport: CGRect {
        visibleRect.inset(by: computedTextContainerInset)
    }

    func convertFromTextContainer(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + computedTextContainerInset.left, y: point.y + computedTextContainerInset.top)
    }

    func convertToTextContainer(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - computedTextContainerInset.left, y: point.y - computedTextContainerInset.top)
    }

    func convertFromTextContainer(_ rect: CGRect) -> CGRect {
        CGRect(origin: convertFromTextContainer(rect.origin), size: rect.size)
    }

    func convertToTextContainer(_ rect: CGRect) -> CGRect {
        CGRect(origin: convertToTextContainer(rect.origin), size: rect.size)
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

        bounds.size.width = textContainer.width

        return bounds
    }

    func didInvalidateLayout(for layoutManager: LayoutManager) {
        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()

        updateInsertionPointTimer()
        inputContext?.invalidateCharacterCoordinates()
        updateFrameHeightIfNeeded()
    }

    func selectionDidChange(for layoutManager: LayoutManager) {
        setTypingAttributes()

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    func defaultAttributes(for layoutManager: LayoutManager) -> AttributedRope.Attributes {
        defaultAttributes
    }

    func layoutManager(_ layoutManager: LayoutManager, attributedRopeFor attrRope: AttributedRope) -> AttributedRope {
        var new = attrRope

        // TODO: this ignores any foregroundColor that's set on buffer.content. Find a better way to do this.
        new.foregroundColor = theme.foregroundColor

        return new.transformingAttributes(\.token) { attr in
            var attributes = theme[attr.value!.type] ?? AttributedRope.Attributes()

            if attributes.font != nil {
                attributes.symbolicTraits = nil
                attributes.fontWeight = nil
            } else {
                // I don't know if making familyName fall back to font.fontName is
                // correct, but it seems like it could be reasonable.
                var d = font
                    .fontDescriptor
                    .withFamily(font.familyName ?? font.fontName)
                    .addingAttributes([.traits: [NSFontDescriptor.TraitKey.weight: attributes.fontWeight ?? .regular]])

                if let symbolicTraits = attributes.symbolicTraits {
                    d = d.withSymbolicTraits(symbolicTraits)
                }

                attributes.font = NSFont(descriptor: d, size: font.pointSize) ?? font
            }

            return attr.replace(with: attributes)
        }
    }
}

extension TextView {
    // MARK: - Text layout

    func layoutTextLayer() {
        textLayer.sublayers = nil

        var scrollAdjustment: CGFloat = 0

        layoutManager.layoutText { line, prevAlignmentFrame in
            let l = textLayerCache[line.id] ?? makeLayer(forLine: line)

            // Without making the layer's bounds aligned to the nearest point
            // I run into an issue where the glyphs seem to shift back and forth
            // by a fraction of a point. I'm not sure why that is given that
            // CALayer.masksToBounds is false.
            l.bounds = line.renderingSurfaceBounds
            l.position = convertFromTextContainer(line.origin)
            textLayerCache[line.id] = l

            textLayer.addSublayer(l)

            let oldHeight = prevAlignmentFrame.height
            let newHeight = line.alignmentFrame.height
            let delta = newHeight - oldHeight
            let oldMaxY = line.origin.y + oldHeight

            // TODO: I don't know why I have to use the previous frame's
            // visible rect here. My best guess is that it has something
            // to do with the fact that I'm doing deferred layout of my
            // sublayers (e.g. textLayer.setNeedsLayout(), etc.). I tried
            // changing the deferred layout calls in prepareContent(in:)
            // to immediate layout calls, but it didn't seem to fix the
            // problem. On the other hand, I'm not sure if I've totally
            // gotten scroll correction right here anyways (there are
            // sometimes things that look like jumps during scrolling).
            // I'll come back to this later.
            if oldMaxY <= previousVisibleRect.minY && delta != 0 {
                scrollAdjustment += delta
            }
        }

        previousVisibleRect = visibleRect

        // Adjust scroll offset.
        // TODO: is it possible to move this into prepareContent(in:) directly?
        // That way it would only happen when we scroll. It's also possible
        // that would let us get rid of previousVisibleRect, but according to
        // the comment below, I tried that, so I'm doubtful.
        if scrollAdjustment != 0 {
            let current = scrollOffset
            scroll(CGPoint(x: current.x, y: current.y + scrollAdjustment))
        }

        updateFrameHeightIfNeeded()
    }

    func makeLayer(forLine line: Line) -> CALayer {
        let l = LineLayer(line: line)
        l.anchorPoint = .zero
        l.needsDisplayOnBoundsChange = true
        l.delegate = self // LineLayerDelegate + NSViewLayerContentScaleDelegate
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
        l.delegate = self // SelectionLayerDelegate +  NSViewLayerContentScaleDelegate
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
        l.delegate = self // InsertionPointLayerDelegate + NSViewLayerContentScaleDelegate
        l.needsDisplayOnBoundsChange = true
        l.contentsScale = window?.backingScaleFactor ?? 1.0
        l.bounds = CGRect(origin: .zero, size: rect.size)
        l.position = convertFromTextContainer(rect.origin)

        return l
    }
}

extension TextView: LineLayerDelegate {
    func effectiveAppearance(for lineLayer: LineLayer) -> NSAppearance {
        effectiveAppearance
    }
}
