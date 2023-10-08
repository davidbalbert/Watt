//
//  LineNumberView.swift
//  Watt
//
//  Created by David Albert on 5/12/23.
//

import Cocoa

class LineNumberView: NSView, CALayerDelegate, NSViewLayerContentScaleDelegate, LayoutManagerLineNumberDelegate {
    @Invalidating(.intrinsicContentSize, .layout) var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular)
    @Invalidating(.intrinsicContentSize, .layout) var leadingPadding: CGFloat = 20
    @Invalidating(.intrinsicContentSize, .layout) var trailingPadding: CGFloat = 5
    @Invalidating(.display) var textColor: NSColor = .secondaryLabelColor
    @Invalidating(.display) var backgroundColor: NSColor = .textBackgroundColor

    var buffer: Buffer {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    var textLayer: CALayer = CALayer()
    var layerCache: WeakDictionary<Int, CALayer> = WeakDictionary()

    override var isFlipped: Bool {
        true
    }

    override var isOpaque: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        self.buffer = Buffer()
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        self.buffer = Buffer()
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        // TODO: subscribe to buffer
        let trackingArea = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .cursorUpdate, .activeInKeyWindow], owner: self)
        addTrackingArea(trackingArea)

        textLayer.delegate = self
    }

    override var intrinsicContentSize: NSSize {
        // max(1000, ...) -> minimum 4 digits worth of space
        let lineCount = max(1000, buffer.lines.count)
        let maxDigits = floor(log10(Double(lineCount))) + 1

        let characters: [UniChar] = Array("0123456789".utf16)
        var glyphs: [CGGlyph] = Array(repeating: 0, count: characters.count)

        let success = CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)

        if !success {
            return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }

        var advances: [CGSize] = Array(repeating: .zero, count: glyphs.count)
        _ = CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)

        let digitWidth = advances.map(\.width).reduce(0, max)

        let width = ceil(digitWidth*maxDigits + leadingPadding + trailingPadding)

        return NSSize(width: width, height: NSView.noIntrinsicMetric)
    }

    override func updateLayer() {
        layer?.backgroundColor = backgroundColor.cgColor

        for l in textLayer.sublayers ?? [] {
            l.setNeedsDisplay()
        }
    }

    override func layout() {
        super.layout()

        guard let layer else {
            return
        }

        if textLayer.superlayer == nil {
            textLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            textLayer.anchorPoint = layer.anchorPoint
            textLayer.position = layer.position
            textLayer.bounds = layer.bounds
            layer.addSublayer(textLayer)
        }
    }

    func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        true
    }

    func layoutManagerShouldUpdateLineNumbers(_ layoutManager: LayoutManager) -> Bool {
        superview != nil
    }

    func layoutManagerWillUpdateLineNumbers(_ layoutManager: LayoutManager) {
        textLayer.sublayers = nil
    }

    func layoutManager(_ layoutManager: LayoutManager, addLineNumber lineno: Int, at position: CGPoint, withLineHeight lineHeight: CGFloat) {
        let l = layerCache[lineno] ?? makeLayer(for: lineno)
        l.position = position
        l.bounds = CGRect(x: 0, y: 0, width: frame.width, height: lineHeight)
        layerCache[lineno] = l
        textLayer.addSublayer(l)
    }

    func layoutManagerDidUpdateLineNumbers(_ layoutManager: LayoutManager) {
        // no-op
    }

    func layoutManager(_ layoutManager: LayoutManager, lineCountDidChangeFrom old: Int, to new: Int) {
        if floor(log10(Double(old))) != floor(log10(Double(new))) {
            invalidateIntrinsicContentSize()
        }
    }

    func makeLayer(for lineNumber: Int) -> CALayer {
        let l = LineNumberLayer(lineNumber: lineNumber, lineNumberView: self)

        l.delegate = self
        l.anchorPoint = .zero
        l.contentsScale = window?.backingScaleFactor ?? 1.0
        l.needsDisplayOnBoundsChange = true

        return l
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }
}
