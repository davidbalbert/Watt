//
//  DocumentViewController.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextViewController: NSViewController {
    var buffer: Buffer = Buffer()

    override func loadView() {
        let scrollView = TextView.scrollableTextView()
        let textView = scrollView.documentView as! TextView
        textView.buffer = buffer
        textView.textContainerInset = NSEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        textView.theme = try! Theme(name: "Default (Light)", withExtension: "xccolortheme")

        view = scrollView
    }
}
