//
//  ClipView.swift
//  Watt
//
//  Created by David Albert on 5/16/23.
//

import Cocoa

protocol ClipViewDelegate: AnyObject {
    func viewDidMoveToClipView(_ clipView: ClipView)
    func clipView(_ clipView: ClipView, frameSizeDidChangeFrom oldSize: NSSize)
}

extension ClipViewDelegate {
    func viewDidMoveToClipView(_ clipView: ClipView) {}
    func clipView(_ clipView: ClipView, frameSizeDidChangeFrom oldSize: NSSize) {}
}

class ClipView: NSClipView {
    weak var delegate: ClipViewDelegate?

    override var documentView: NSView? {
        didSet {
            delegate?.viewDidMoveToClipView(self)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        let old = frame.size
        super.setFrameSize(newSize)
        delegate?.clipView(self, frameSizeDidChangeFrom: old)
    }
}

