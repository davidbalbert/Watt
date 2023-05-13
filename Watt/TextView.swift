//
//  TextView.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextView<Storage>: NSView, NSViewLayerContentScaleDelegate where Storage: TextStorage {
    typealias TextContainer = LayoutManager<Storage>.TextContainer
    typealias LayoutFragment = LayoutManager<Storage>.LayoutFragment

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

    var lineNumberView: LineNumberView
    var textContainer: TextContainer

    var textContainerInset: CGSize {
        CGSize(width: lineNumberView.frame.width, height: 0)
    }

    var fragmentLayerMap: WeakDictionary<LayoutFragment.ID, TextLayer<Storage>>
    var textLayer: CALayer = NonAnimatingLayer()

    override init(frame frameRect: NSRect) {
        storage = Storage("")
        layoutManager = LayoutManager<Storage>()
        textContainer = TextContainer()
        fragmentLayerMap = WeakDictionary()
        lineNumberView = LineNumberView()
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        storage = Storage("")
        layoutManager = LayoutManager<Storage>()
        textContainer = TextContainer()
        fragmentLayerMap = WeakDictionary()
        lineNumberView = LineNumberView()
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        textContainer.size = CGSize(width: bounds.width, height: 0)
        layoutManager.delegate = self
        layoutManager.textContainer = textContainer
        storage.addLayoutManager(layoutManager)
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false
        lineNumberView.delegate = self
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
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

    override func layout() {
        guard let layer else {
            return
        }

        if textLayer.superlayer == nil {
            textLayer.anchorPoint = .zero
            textLayer.bounds = layer.bounds
            layer.addSublayer(textLayer)
        }

        layoutLineNumberView()
        layoutManager.layoutViewport()
    }

    override func prepareContent(in rect: NSRect) {
        super.prepareContent(in: rect)
        layoutManager.layoutViewport()
    }

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        removeLineNumberView()
    }

    override func viewDidMoveToSuperview() {
        addLineNumberView()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        if (textContainer.size.width != frame.width) {
            updateTextContainerSize()
        }
    }

    func updateTextContainerSize() {
        textContainer.size = CGSize(width: frame.width - textContainerInset.width, height: 0)
    }
}
