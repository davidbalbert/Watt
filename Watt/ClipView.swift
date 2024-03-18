//
//  ClipView.swift
//  Watt
//
//  Created by David Albert on 5/16/23.
//

import Cocoa

protocol ClipViewDelegate: AnyObject {
    func viewDidMoveToClipView(_ clipView: ClipView)
}

extension ClipViewDelegate {
    func viewDidMoveToClipView(_ clipView: ClipView) {}
}

class ClipView: NSClipView {
    weak var delegate: ClipViewDelegate?

    override var documentView: NSView? {
        didSet {
            delegate?.viewDidMoveToClipView(self)
        }
    }
}

