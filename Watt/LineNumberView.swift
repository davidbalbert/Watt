//
//  LineNumberView.swift
//  Watt
//
//  Created by David Albert on 5/12/23.
//

import Cocoa

class LineNumberView: NSView {
    weak var delegate: LineNumberViewDelegate?

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
        NotificationCenter.default.addObserver(self, selector: #selector(frameDidChange(_:)), name: NSView.frameDidChangeNotification, object: self)
    }

    override func updateLayer() {
        // no-op
    }

    let g: CAGradientLayer = CAGradientLayer()
    override func layout() {
        guard let layer else {
            return
        }

        if g.superlayer == nil {
            g.colors = [NSColor.red.cgColor, NSColor.green.cgColor]
            g.autoresizingMask = [.layerHeightSizable]
            g.anchorPoint = layer.anchorPoint
            g.position = layer.position
            g.bounds = layer.bounds
            layer.addSublayer(g)
        }
    }

    @objc func frameDidChange(_ notification: NSNotification) {
        delegate?.lineNumberViewFrameDidChange(notification)
    }
}
