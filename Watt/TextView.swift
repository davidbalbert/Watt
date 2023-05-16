//
//  TextView.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextView<Content>: NSView, NSViewLayerContentScaleDelegate, ClipViewDelegate where Content: TextContent {
    typealias TextContainer = LayoutManager<Content>.TextContainer
    typealias LayoutFragment = LayoutManager<Content>.LayoutFragment

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
            textContent.didSetFont(to: font)
            layoutManager.invalidateLayout()
            lineNumberView.font = font
        }
    }

    var textContent: Content {
        didSet {
            oldValue.removeLayoutManager(layoutManager)
            textContent.addLayoutManager(layoutManager)

            textContent.didSetFont(to: font)
            needsLayout = true
        }
    }

    var layoutManager: LayoutManager<Content> {
        didSet {
            oldValue.delegate = nil
            textContent.removeLayoutManager(oldValue)

            layoutManager.delegate = self
            textContent.addLayoutManager(layoutManager)

            needsLayout = true
        }
    }

    var lineNumberView: LineNumberView
    var textContainer: TextContainer

    var textContainerInset: CGSize {
        CGSize(width: lineNumberView.frame.width, height: 0)
    }

    var fragmentLayerMap: WeakDictionary<LayoutFragment.ID, TextLayer<Content>>
    var textLayer: CALayer = NonAnimatingLayer()

    override init(frame frameRect: NSRect) {
        textContent = Content("")
        layoutManager = LayoutManager<Content>()
        textContainer = TextContainer()
        fragmentLayerMap = WeakDictionary()
        lineNumberView = LineNumberView()
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        textContent = Content("")
        layoutManager = LayoutManager<Content>()
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
        textContent.addLayoutManager(layoutManager)
        lineNumberView.delegate = self
        lineNumberView.font = font
        textContent.didSetFont(to: font)
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
