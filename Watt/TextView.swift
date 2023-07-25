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
            lineNumberView.font = font

            layoutManager.invalidateLayout()

            selectionLayer.setNeedsLayout()
            textLayer.setNeedsLayout()
            insertionPointLayer.setNeedsLayout()
        }
    }

    var buffer: Buffer {
        didSet {
            layoutManager.buffer = buffer

            selectionLayer.setNeedsLayout()
            textLayer.setNeedsLayout()
            insertionPointLayer.setNeedsLayout()
        }
    }

    let layoutManager: LayoutManager

    var selection: Selection? {
        layoutManager.selection
    }

    var lineNumberView: LineNumberView

    // Exposed so users of TextView can set textContainer.lineFragmentPadding.
    // The size of the TextContainer is managed by the TextView. If you set
    // size, it will be immediately overwritten.
    var textContainer: TextContainer {
        get {
            layoutManager.textContainer
        }
        set {
            layoutManager.textContainer = newValue
            updateTextContainerSizeIfNeeded()
        }
    }

    var textContainerInset: NSEdgeInsets = NSEdgeInsetsZero {
        didSet {
            if !NSEdgeInsetsEqual(textContainerInset, oldValue) {
                updateComputedTextContainerInset()
                layoutManager.invalidateLayout()
            }
        }
    }

    // internal, for use with the line number view
    var computedTextContainerInset: NSEdgeInsets = NSEdgeInsetsZero

    let selectionLayer: CALayer = CALayer()
    let textLayer: CALayer = CALayer()
    let insertionPointLayer: CALayer = CALayer()

//    var textLayerCache: WeakDictionary<LayoutFragment.ID, CALayer> = WeakDictionary()
//    var selectionLayerCache: WeakDictionary<CGRect, CALayer> = WeakDictionary()
//    var insertionPointLayerCache: WeakDictionary<CGRect, CALayer> = WeakDictionary()

    var insertionPointTimer: Timer?

    override init(frame frameRect: NSRect) {
        buffer = Buffer()
        layoutManager = LayoutManager()
        lineNumberView = LineNumberView()
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        buffer = Buffer()
        layoutManager = LayoutManager()
        lineNumberView = LineNumberView()
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        layoutManager.buffer = buffer

        layoutManager.delegate = self
        layoutManager.lineNumberDelegate = lineNumberView
        
        lineNumberView.buffer = buffer
        lineNumberView.font = font
        lineNumberView.translatesAutoresizingMaskIntoConstraints = false

        NotificationCenter.default.addObserver(self, selector: #selector(lineNumberViewFrameDidChange(_:)), name: NSView.frameDidChangeNotification, object: lineNumberView)

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

        let trackingArea = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .cursorUpdate, .activeInKeyWindow], owner: self)
        addTrackingArea(trackingArea)

        updateInsertionPointTimer()
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    }

    override func viewWillMove(toSuperview newSuperview: NSView?) {
        removeLineNumberView()
    }

    // This is a custom method on ClipViewDelegate. Normally we'd use
    // viewDidMoveToSuperview, but when we're added to a clip view,
    // that's called too early – specifically, it's called before the
    // clip view has had a chance to match its isFlipped property to
    // ours. So instead, we define a custom ClipView that calls this
    // method after setDocumentView: is finished and the clip view
    // has had a chance to update its geometry.
    //
    // If we don't do this, the LineNumberView is flipped upside down.
    func viewDidMoveToClipView() {
        addLineNumberView()
    }
}
