//
//  DocumentViewController.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextViewController: NSViewController {
    var buffer: Buffer

    init(_ buffer: Buffer) {
        self.buffer = buffer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let scrollView = TextView.scrollableTextView()
        let textView = scrollView.documentView as! TextView
        textView.buffer = buffer

        view = scrollView
    }
}
