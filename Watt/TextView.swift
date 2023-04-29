//
//  TextView.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextView<Storage>: NSView where Storage: TextStorage {
    class func scrollableTextView() -> NSScrollView {
        let textView = Self()

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView

        textView.autoresizingMask = [.width, .height]

        return scrollView
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

    required init() {
        storage = Storage("")
        layoutManager = LayoutManager()
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        storage = Storage("")
        layoutManager = LayoutManager()
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
        layoutManager.delegate = self
        storage.addLayoutManager(layoutManager)
    }

    override func updateLayer() {
        // No-op. Here to ensure we're layer-backed.
    }

    override func layout() {
        layoutManager.layoutViewport()
    }
}
