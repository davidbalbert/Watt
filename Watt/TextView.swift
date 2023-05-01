//
//  TextView.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextView: NSView {
    class func scrollableTextView() -> NSScrollView {
        let textView = Self()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView

        textView.autoresizingMask = [.width, .height]

        return scrollView
    }

//    override var isFlipped: Bool {
//        true
//    }

    override var isOpaque: Bool {
        true
    }

    var storage: TextStorage {
        didSet {
            oldValue.removeLayoutManager(layoutManager)
            storage.addLayoutManager(layoutManager)
        }
    }

    var layoutManager: LayoutManager {
        didSet {
            oldValue.delegate = nil
            storage.removeLayoutManager(oldValue)

            layoutManager.delegate = self
            storage.addLayoutManager(layoutManager)
        }
    }

    var textLayer: CALayer = NonAnimatingLayer()

    required init() {
        storage = NullTextStorage()
        layoutManager = LayoutManager()
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        storage = NullTextStorage()
        layoutManager = LayoutManager()
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        layoutManager.delegate = self
        storage.addLayoutManager(layoutManager)
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    }
}
