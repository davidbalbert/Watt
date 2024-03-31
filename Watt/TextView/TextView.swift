//
//  TextView.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextView: NSView, ClipViewDelegate {
    override var isFlipped: Bool {
        true
    }

    override var isOpaque: Bool {
        true
    }

    override var needsDisplay: Bool {
        didSet {
            setTextNeedsDisplay()
            setSelectionNeedsDisplay()
            setInsertionPointNeedsDisplay()
        }
    }

    var font: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular) {
        didSet {
            buffer.contents.font = font
            lineNumberView.font = font
            typingAttributes.font = font
            defaultAttributes.font = font

            layoutManager.invalidateLayout()
        }
    }

    var theme: Theme = .system {
        didSet {
            defaultAttributes.foregroundColor = theme.foregroundColor
            layoutManager.invalidateLayout()
            needsDisplay = true
            
            lineNumberView.textColor = theme.lineNumberColor
            lineNumberView.backgroundColor = theme.backgroundColor
        }
    }

    var foregroundColor: NSColor {
        get { theme.foregroundColor }
        set {
            theme.foregroundColor = newValue
            defaultAttributes.foregroundColor = newValue
        }
    }

    var backgroundColor: NSColor {
        get { theme.backgroundColor }
        set { theme.backgroundColor = newValue }
    }

    var insertionPointColor: NSColor {
        get { theme.insertionPointColor }
        set { theme.insertionPointColor = newValue }
    }

    var selectedTextBackgroundColor: NSColor {
        get { theme.selectedTextBackgroundColor }
        set { theme.selectedTextBackgroundColor = newValue }
    }

    var lineNumberColor: NSColor {
        get { theme.lineNumberColor }
        set { theme.lineNumberColor = newValue }
    }

    lazy var defaultAttributes: AttributedRope.Attributes = {
        AttributedRope.Attributes
            .font(font)
            .foregroundColor(foregroundColor)
    }()

    lazy var typingAttributes: AttributedRope.Attributes = defaultAttributes

    var markedTextAttributes: AttributedRope.Attributes {
        theme.markedTextAttributes
    }

    var buffer: Buffer {
        get {
            layoutManager.buffer
        }
        set {
            layoutManager.buffer = newValue
        }
    }

    let layoutManager: LayoutManager

    var selection: Selection {
        didSet {
            setTypingAttributes()

            needsSelectionLayout = true
            needsInsertionPointLayout = true
            updateInsertionPointTimer()
        }
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

    var needsTextLayout: Bool = false {
        didSet {
            if needsTextLayout {
                needsLayout = true
            }
        }
    }
    var needsSelectionLayout: Bool = false {
        didSet {
            if needsSelectionLayout {
                needsLayout = true
            }
        }
    }
    var needsInsertionPointLayout: Bool = false {
        didSet {
            if needsInsertionPointLayout {
                needsLayout = true
            }
        }
    }

    var performingLayout: Bool = false

    var selectionLayerCache: WeakDictionary<CGRect, CALayer> = WeakDictionary()
    var insertionPointLayerCache: WeakDictionary<CGRect, CALayer> = WeakDictionary()
    var insertionPointTimer: Timer?

    lazy var scrollManager: ScrollManager = {
        ScrollManager(self)
    }()
    var autoscroller: Autoscroller?

    override init(frame frameRect: NSRect) {
        layoutManager = LayoutManager()
        lineNumberView = LineNumberView()
        selection = Selection(atStartOf: layoutManager.buffer)
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        layoutManager = LayoutManager()
        lineNumberView = LineNumberView()
        selection = Selection(atStartOf: layoutManager.buffer)
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        layerContentsRedrawPolicy = .onSetNeedsDisplay

        layoutManager.buffer = buffer
        layoutManager.delegate = self

        lineNumberView.lineCount = buffer.lines.count
        lineNumberView.font = font
        lineNumberView.textColor = theme.lineNumberColor
        lineNumberView.backgroundColor = backgroundColor
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

    override func viewDidMoveToSuperview() {
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)

        if let scrollView {
            NotificationCenter.default.addObserver(self, selector: #selector(viewDidScroll), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        }

        scrollManager.viewDidMoveToSuperview()
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
    func viewDidMoveToClipView(_ clipView: ClipView) {
        addLineNumberView()
    }

    // Necessary (as opposed to observing boundsDidChangeNotification) because
    // we need to know both the old size and new size of the clip view.
    func clipView(_ clipView: ClipView, frameSizeDidChangeFrom oldSize: NSSize) {
        let heightChanged = oldSize.height != clipView.frame.height
        let widthChanged = oldSize.width != clipView.frame.width

        if heightChanged || (widthChanged && textContainer.width < .greatestFiniteMagnitude) {
            needsTextLayout = true
            needsSelectionLayout = true
            needsInsertionPointLayout = true
        }
    }

    override func viewDidMoveToWindow() {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)

        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)

            needsTextLayout = true
            needsSelectionLayout = true
            needsInsertionPointLayout = true
        }
    }
}
