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

    weak var delegate: LineNumberViewDelegate?

    var textLayer: CALayer = CALayer()
    var layerCache: WeakDictionary<Int, CALayer> = WeakDictionary()

    override var isFlipped: Bool {
        true
    }

    override var isOpaque: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        NotificationCenter.default.addObserver(self, selector: #selector(frameDidChange(_:)), name: NSView.frameDidChangeNotification, object: self)

        let trackingArea = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .cursorUpdate, .activeInKeyWindow], owner: self)
        addTrackingArea(trackingArea)
    }

    private var _intrinsicContentSize: NSSize?

    override func invalidateIntrinsicContentSize() {
        _intrinsicContentSize = nil
        super.invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        if let _intrinsicContentSize {
            return _intrinsicContentSize
        }

        let size = calculateIntrinsicContentSize()
        _intrinsicContentSize = size
        return size
    }

    // TODO: AppKit may already be caching intrinsicContentSize. See if we can put this right in the definition of intrinsicContentSize and see if it gets called more often. If it doesn't, get rid of our own caching behavior.
    func calculateIntrinsicContentSize() -> NSSize {
        guard let delegate else {
            return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }

        // max(100, ...) -> minimum 3 digits worth of space
        let lineCount = max(100, delegate.lineCount(for: self))
        let maxDigits = floor(log10(CGFloat(lineCount))) + 1

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
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        for l in textLayer.sublayers ?? [] {
            l.setNeedsDisplay()
        }
    }

    override func layout() {
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

    func layoutSublayers(of layer: CALayer) {
        switch layer {
        case textLayer:
            layoutTextLayer()
        default:
            break
        }
    }

    func layoutTextLayer() {
        for l in textLayer.sublayers ?? [] {
            l.bounds.size.width = frame.width
        }
    }

    func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        true
    }

    @objc func frameDidChange(_ notification: NSNotification) {
        delegate?.lineNumberViewFrameDidChange(notification)
    }

    func beginUpdates() {
        textLayer.sublayers = nil
    }

    func addLineNumber(_ lineno: Int, at position: CGPoint, withLineHeight lineHeight: CGFloat) {
        let l = layerCache[lineno] ?? makeLayer(for: lineno)
        l.position = position
        l.bounds = CGRect(x: 0, y: 0, width: frame.width, height: lineHeight)
        layerCache[lineno] = l
        textLayer.addSublayer(l)
    }

    func endUpdates() {
        // no-op
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
