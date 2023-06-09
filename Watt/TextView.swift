//
//  TextView.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextView: NSView, ClipViewDelegate {
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
            selectionLayer.setNeedsLayout()
        }
    }

    var contentManager: ContentManager {
        didSet {
            oldValue.removeLayoutManager(layoutManager)
            contentManager.addLayoutManager(layoutManager)

            contentManager.didSetFont(to: font)

            layoutManager.selection = Selection(head: contentManager.documentRange.lowerBound)
            textLayer.setNeedsLayout()
            selectionLayer.setNeedsLayout()
        }
    }

    var layoutManager: LayoutManager {
        didSet {
            oldValue.delegate = nil
            contentManager.removeLayoutManager(oldValue)

            layoutManager.delegate = self

            contentManager.addLayoutManager(layoutManager)

            layoutManager.selection = Selection(head: contentManager.documentRange.lowerBound)
            textLayer.setNeedsLayout()
            selectionLayer.setNeedsLayout()
        }
    }

    var selection: Selection? {
        layoutManager.selection
    }

    var lineNumberView: LineNumberView
    var textContainer: TextContainer

    var textContainerInset: CGSize {
        CGSize(width: lineNumberView.frame.width, height: 0)
    }

    let textLayer: CALayer = CALayer()
    let selectionLayer: CALayer = CALayer()
    let insertionPointLayer: CALayer = CALayer()

    var textLayerCache: WeakDictionary<LayoutFragment.ID, CALayer> = WeakDictionary()
    var selectionLayerCache: WeakDictionary<CGRect, CALayer> = WeakDictionary()
    var insertionPointLayerCache: WeakDictionary<CGRect, CALayer> = WeakDictionary()

    var insertionPointTimer: Timer?

    override init(frame frameRect: NSRect) {
        contentManager = ContentManager("")
        layoutManager = LayoutManager()
        textContainer = TextContainer()
        lineNumberView = LineNumberView()
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        contentManager = ContentManager("")
        layoutManager = LayoutManager()
        textContainer = TextContainer()
        lineNumberView = LineNumberView()
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        textContainer.size = CGSize(width: bounds.width, height: 0)

        layoutManager.delegate = self
        layoutManager.textContainer = textContainer

        contentManager.addLayoutManager(layoutManager)

        lineNumberView.delegate = self
        lineNumberView.font = font
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false

        selectionLayer.name = "Selections"
        selectionLayer.anchorPoint = .zero
        selectionLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        selectionLayer.delegate = self

        textLayer.name = "Text"
        textLayer.anchorPoint = .zero
        textLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        textLayer.delegate = self

        insertionPointLayer.name = "Insertion points"
        insertionPointLayer.anchorPoint = .zero
        insertionPointLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        insertionPointLayer.delegate = self

        layoutManager.selection = Selection(head: contentManager.documentRange.lowerBound)

        let trackingArea = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .cursorUpdate, .activeInKeyWindow], owner: self)
        addTrackingArea(trackingArea)

        contentManager.didSetFont(to: font)

        updateInsertionPointTimer()
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
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
}
