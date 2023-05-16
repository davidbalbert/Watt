//
//  LineNumberView.swift
//  Watt
//
//  Created by David Albert on 5/12/23.
//

import Cocoa

class LineNumberView: NSView {
    static let lineNumberKey = "lineNumber"

    var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular)

    // TODO: ask our delgate what the total number of lines is
    weak var delegate: LineNumberViewDelegate?

    var textLayer: NonAnimatingLayer = NonAnimatingLayer()
    var layerDelegate: LayerDelegate = LayerDelegate()
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
        layerDelegate.lineNumberView = self
        NotificationCenter.default.addObserver(self, selector: #selector(frameDidChange(_:)), name: NSView.frameDidChangeNotification, object: self)
    }

    override func updateLayer() {
        // no-op
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

    @objc func frameDidChange(_ notification: NSNotification) {
        delegate?.lineNumberViewFrameDidChange(notification)
    }

    func beginUpdates() {
        textLayer.sublayers = nil
    }

    func addLineNumber(_ lineno: Int, at position: CGPoint, withLineHeight lineHeight: CGFloat) {
        if let l = layerCache[lineno] {
            l.position = position
            textLayer.addSublayer(l)
            return
        }

        let l = CALayer()
        l.setValue(lineno, forKey: LineNumberView.lineNumberKey)
        l.delegate = layerDelegate
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
