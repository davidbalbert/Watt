//
//  TextView.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextView<ContentManager>: NSView, NSViewLayerContentScaleDelegate, ClipViewDelegate where ContentManager: TextContentManager {
    typealias TextContainer = LayoutManager<ContentManager>.TextContainer
    typealias LayoutFragment = LayoutManager<ContentManager>.LayoutFragment

    class func scrollableTextView() -> NSScrollView {
        let textView = Self()

        let scrollView = NSScrollView()
        scrollView.contentView = ClipView()
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

    var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular) {
        didSet {
            contentManager.didSetFont(to: font)
            lineNumberView.font = font

            layoutManager.invalidateLayout()
            textLayer.setNeedsLayout()
        }
    }

    var contentManager: ContentManager {
        didSet {
            oldValue.removeLayoutManager(layoutManager)
            contentManager.addLayoutManager(layoutManager)

            contentManager.didSetFont(to: font)
            textLayer.setNeedsLayout()
        }
    }

    var layoutManager: LayoutManager<ContentManager> {
        didSet {
            oldValue.delegate = nil
            contentManager.removeLayoutManager(oldValue)

            layoutManager.delegate = textLayerLayout
            textLayerLayout.layoutManager = layoutManager

            contentManager.addLayoutManager(layoutManager)

            textLayer.setNeedsLayout()
        }
    }

    var lineNumberView: LineNumberView
    var textContainer: TextContainer

    var textContainerInset: CGSize {
        CGSize(width: lineNumberView.frame.width, height: 0)
    }

    let textLayer: CALayer = CALayer()
    let textLayerLayout: TextLayerLayout<ContentManager> = TextLayerLayout()

    override init(frame frameRect: NSRect) {
        contentManager = ContentManager("")
        layoutManager = LayoutManager<ContentManager>()
        textContainer = TextContainer()
        lineNumberView = LineNumberView()
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        contentManager = ContentManager("")
        layoutManager = LayoutManager<ContentManager>()
        textContainer = TextContainer()
        lineNumberView = LineNumberView()
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        textContainer.size = CGSize(width: bounds.width, height: 0)

        layoutManager.delegate = textLayerLayout
        layoutManager.textContainer = textContainer

        contentManager.addLayoutManager(layoutManager)

        lineNumberView.delegate = self
        lineNumberView.font = font
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false

        textLayerLayout.layoutManager = layoutManager
        textLayerLayout.delegate = self

        textLayer.name = "Text Layer"
        textLayer.delegate = textLayerLayout

        contentManager.didSetFont(to: font)
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

        super.layout()
    }

    override func prepareContent(in rect: NSRect) {
        super.prepareContent(in: rect)
        textLayer.setNeedsLayout()
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

        updateTextContainerSizeIfNecessary()
    }

    func updateTextContainerSizeIfNecessary() {
        let width = max(0, frame.width - textContainerInset.width)

        if textContainer.size.width != width {
            textContainer.size = CGSize(width: width, height: 0)
        }
    }
}
