//
//  TextView.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextView<Storage>: NSView, NSViewLayerContentScaleDelegate, ClipViewDelegate where Storage: TextStorage {
    typealias TextContainer = LayoutManager<Storage>.TextContainer
    typealias LayoutFragment = LayoutManager<Storage>.LayoutFragment

    class func scrollableTextView() -> NSScrollView {
        let textView = Self()

        let scrollView = NSScrollView()
//        print(scrollView.contentView.autoresizingMask)
        scrollView.contentView = ClipView()
//        print(scrollView.contentView.autoresizingMask)

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

    @Invalidating(.layout) var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular) {
        didSet {
            storage.didSetFont(to: font)
            layoutManager.invalidateLayout()
            lineNumberView.font = font
        }
    }

    var storage: Storage {
        didSet {
            oldValue.removeLayoutManager(layoutManager)
            storage.addLayoutManager(layoutManager)

            storage.didSetFont(to: font)
            needsLayout = true
        }
    }

    var layoutManager: LayoutManager<Storage> {
        didSet {
            oldValue.delegate = nil
            storage.removeLayoutManager(oldValue)

            layoutManager.delegate = self
            storage.addLayoutManager(layoutManager)

            needsLayout = true
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
        lineNumberView.delegate = self
        lineNumberView.font = font
        storage.didSetFont(to: font)
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
            textLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer.addSublayer(textLayer)
        }

        layoutLineNumberView()
        layoutManager.layoutViewport()
    }

    override func prepareContent(in rect: NSRect) {
        super.prepareContent(in: rect)
        needsLayout = true
    }

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        removeLineNumberView()
    }

    // This is a custom method on ClipViewDelegate. Normally we'd use
    // viewDidMoveToSuperview, but when we're added to a scroll view,
    // that's called too early – specifically, it's called before the
    // clip view has had a chance to match its isFlipped property to
    // ours. So instead, we define a custom ClipView that calls this
    // method after setDocumentView: is finished and the clip view
    // has had a chance to update its geometry.
    func viewDidMoveToClipView() {
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
