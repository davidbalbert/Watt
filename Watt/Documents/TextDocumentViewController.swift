//
//  TextDocumentViewController.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextDocumentViewController: DocumentViewController {
    var buffer: Buffer
    
    init(buffer: Buffer) {
        self.buffer = buffer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        let scrollView = TextView.scrollableTextView()
        let textView = scrollView.documentView as! TextView
        textView.buffer = buffer
        textView.textContainerInset = NSEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        textView.theme = try! Theme(name: "Default (Light)", withExtension: "xccolortheme")

        view = scrollView
    }
}
