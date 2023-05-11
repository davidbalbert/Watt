//
//  TextView.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextView<Storage>: NSView, NSViewLayerContentScaleDelegate where Storage: TextStorage {
    class func scrollableTextView() -> NSScrollView {
        let textView = Self()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView

        textView.autoresizingMask = [.width, .height]

        return scrollView
    }

    override var isFlipped: Bool {
        true
    }

    override var isOpaque: Bool {
        true
    }

    var storage: Storage {
        didSet {
            oldValue.removeLayoutManager(layoutManager)
            storage.addLayoutManager(layoutManager)
        }
    }

    var layoutManager: LayoutManager<Storage> {
        didSet {
            oldValue.delegate = nil
            storage.removeLayoutManager(oldValue)

            layoutManager.delegate = self
            storage.addLayoutManager(layoutManager)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        if (textContainer.size.width != frame.width) {
            textContainer.size = CGSize(width: frame.width, height: 0)
        }
    }

    var textContainer: TextContainer<Storage>

    var textLayer: CALayer = NonAnimatingLayer()

    required init() {
        storage = Storage("")
        layoutManager = LayoutManager<Storage>()
        textContainer = TextContainer()
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        storage = Storage("")
        layoutManager = LayoutManager<Storage>()
        textContainer = TextContainer()
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        textContainer.size = CGSize(width: bounds.width, height: 0)
        layoutManager.delegate = self
        layoutManager.textContainer = textContainer
        storage.addLayoutManager(layoutManager)
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    }

    func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        true
    }

    override func layout() {
        guard let layer else {
            return
        }

        if textLayer.superlayer == nil {
            textLayer.anchorPoint = .zero
            textLayer.bounds = layer.bounds
            layer.addSublayer(textLayer)
        }

        layoutManager.layoutViewport()
    }

    override func prepareContent(in rect: NSRect) {
        super.prepareContent(in: rect)
        layoutManager.layoutViewport()
    }
}
