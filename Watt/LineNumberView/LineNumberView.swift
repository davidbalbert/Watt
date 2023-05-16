//
//  LineNumberView.swift
//  Watt
//
//  Created by David Albert on 5/12/23.
//

import Cocoa

class LineNumberView: NSView {
    static let lineNumberKey = "lineNumber"

    @Invalidating(.intrinsicContentSize, .layout) var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular)

    @Invalidating(.intrinsicContentSize, .layout) var leadingPadding: CGFloat = 20
    @Invalidating(.intrinsicContentSize, .layout) var trailingPadding: CGFloat = 5
    @Invalidating(.display) var textColor: NSColor = .secondaryLabelColor

    weak var delegate: LineNumberViewDelegate?

    var textLayer: NonAnimatingLayer = NonAnimatingLayer()
    var renderer: LineNumberRenderer = LineNumberRenderer()
    var layerCache: WeakDictionary<Int, CALayer> = WeakDictionary()

    override var isFlipped: Bool {
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
        renderer.lineNumberView = self
        NotificationCenter.default.addObserver(self, selector: #selector(frameDidChange(_:)), name: NSView.frameDidChangeNotification, object: self)
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

        let width = digitWidth*maxDigits + leadingPadding + trailingPadding

        return NSSize(width: width, height: NSView.noIntrinsicMetric)
    }

    override func updateLayer() {
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

        for l in textLayer.sublayers ?? [] {
            l.bounds.size.width = frame.width
        }
    }

    @objc func frameDidChange(_ notification: NSNotification) {
        delegate?.lineNumberViewFrameDidChange(notification)
    }

    func beginUpdates() {
        textLayer.sublayers = nil
    }

    func addLineNumber(_ lineno: Int, at position: CGPoint, withLineHeight lineHeight: CGFloat) {
        let l = layerCache[lineno] ?? CALayer()

        l.setValue(lineno, forKey: LineNumberView.lineNumberKey)
        l.delegate = renderer
        l.contentsScale = window?.backingScaleFactor ?? 1.0
        l.needsDisplayOnBoundsChange = true
        l.anchorPoint = .zero
        l.position = position

        l.bounds = CGRect(x: 0, y: 0, width: frame.width, height: lineHeight)

        layerCache[lineno] = l
        textLayer.addSublayer(l)
    }

    func endUpdates() {
        // no-op
    }
}
