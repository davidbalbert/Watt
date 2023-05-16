//
//  ClipView.swift
//  Watt
//
//  Created by David Albert on 5/16/23.
//

import Cocoa

protocol ClipViewDelegate: AnyObject {
    func viewDidMoveToClipView()
}

class ClipView: NSClipView {
    override var documentView: NSView? {
        didSet {
            (documentView as? ClipViewDelegate)?.viewDidMoveToClipView()
        }
    }
}

