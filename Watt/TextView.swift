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
            buffer.contents.font = font
            lineNumberView.font = font
            typingAttributes.font = font

            layoutManager.invalidateLayout()
        }
    }

    var backgroundColor: NSColor {
        theme.backgroundColor
    }

    var theme: Theme = .defaultTheme {
        didSet {
            layoutManager.invalidateLayout()
            needsDisplay = true
        }
    }

    var defaultAttributes: AttributedRope.Attributes {
        AttributedRope.Attributes([
               .font: font
       ])
    }

    lazy var typingAttributes: AttributedRope.Attributes = defaultAttributes

    // TODO: get this from Theme.
    // Maybe make Theme into a protocol so that we can have a NullTheme
    // which returns this, as well as textBackgroundColor for the view's
    // background color.
    var markedTextAttributes: AttributedRope.Attributes {
        AttributedRope.Attributes([
            .backgroundColor: NSColor.systemYellow.withSystemEffect(.disabled),
        ])
    }

    var buffer: Buffer {
        didSet {
            // mergeAttributes instead of setAttributes because highlighting
            // already happened at Buffer creation. I want to find a more
            // principled way to trigger highlighting.
            buffer.mergeAttributes(defaultAttributes)

            oldValue.removeLayoutManager(layoutManager)
            buffer.addLayoutManager(layoutManager)

            lineNumberView.buffer = buffer

            layoutManager.invalidateLayout()
        }
    }

    let layoutManager: LayoutManager

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

    var selectionLayerCache: WeakDictionary<CGRect, CALayer> = WeakDictionary()
    var textLayerCache: WeakDictionary<Line.ID, CALayer> = WeakDictionary()
    var insertionPointLayerCache: WeakDictionary<CGRect, CALayer> = WeakDictionary()

    var insertionPointTimer: Timer?

    // HACK: See layoutTextLayer() for context.
    var previousVisibleRect: CGRect = .zero

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
        layer?.backgroundColor = theme.backgroundColor.cgColor
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

    override func viewDidMoveToWindow() {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)

        guard let window else {
            return
        }

        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey(_:)), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey(_:)), name: NSWindow.didResignKeyNotification, object: window)
    }
}
