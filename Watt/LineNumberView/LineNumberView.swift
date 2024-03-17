//
//  LineNumberView.swift
//  Watt
//
//  Created by David Albert on 5/12/23.
//

import Cocoa

class LineNumberView: NSView, CALayerDelegate, NSViewLayerContentScaleDelegate {
    @Invalidating(.intrinsicContentSize, .layout) var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular)
    @Invalidating(.intrinsicContentSize, .layout) var leadingPadding: CGFloat = 20
    @Invalidating(.intrinsicContentSize, .layout) var trailingPadding: CGFloat = 5
    @Invalidating(.display) var textColor: NSColor = .secondaryLabelColor
    @Invalidating(.display) var backgroundColor: NSColor = .textBackgroundColor

    private var _lineCount: Int {
        didSet {
            if floor(log10(Double(oldValue))) != floor(log10(Double(lineCount))) {
                invalidateIntrinsicContentSize()
            }
        }
    }
    var lineCount: Int {
        get { _lineCount }
        set { _lineCount = max(newValue, 1) }
    }

    var textLayer: CALayer = CALayer()
    var lineNumberLayers: [LineNumberLayer] = []
    var newLayers: [LineNumberLayer] = []

    override var isFlipped: Bool {
        true
    }

    override var isOpaque: Bool {
        true
    }

    override var needsDisplay: Bool {
        didSet {
            for l in textLayer.sublayers ?? [] {
                l.setNeedsDisplay()
            }
        }
    }

    override init(frame frameRect: NSRect) {
        _lineCount = 1
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        _lineCount = 1
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        let trackingArea = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .cursorUpdate, .activeInKeyWindow], owner: self)
        addTrackingArea(trackingArea)

        textLayer.delegate = self
    }

    override var intrinsicContentSize: NSSize {
        // max(1000, ...) -> minimum 4 digits worth of space
        let lineCount = max(1000, lineCount)
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

    func beginUpdates() {
        newLayers = []
    }

    // Must be called in ascending lineno order.
    func addLineNumber(_ lineno: Int, withAlignmentFrame alignmentFrame: CGRect) {
        let l = existingLayer(for: lineno) ?? makeLayer(for: lineno)
        l.position = alignmentFrame.origin
        l.bounds = CGRect(x: 0, y: 0, width: frame.width, height: alignmentFrame.height)
        newLayers.append(l)
    }

    func endUpdates() {
        lineNumberLayers = newLayers
        textLayer.setSublayers(to: lineNumberLayers)
        newLayers = []
    }

    func existingLayer(for lineno: Int) -> LineNumberLayer? {
        let (i, found) = lineNumberLayers.binarySearch { $0.lineNumber.compare(to: lineno) }
        if found {
            return lineNumberLayers[i]
        }
        return nil
    }

    func makeLayer(for lineNumber: Int) -> LineNumberLayer {
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
