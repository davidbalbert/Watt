//
//  DocumentViewController.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextViewController: NSViewController {
    var storage: AttributedStringStorage

    init(_ storage: AttributedStringStorage) {
        self.storage = storage
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let scrollView = TextView<AttributedStringStorage>.scrollableTextView()
        let textView = scrollView.documentView as! TextView<AttributedStringStorage>
        textView.storage = storage

        view = scrollView
    }
}
