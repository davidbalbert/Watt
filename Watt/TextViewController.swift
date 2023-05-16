//
//  DocumentViewController.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextViewController: NSViewController {
    var textContent: AttributedStringContent

    init(_ textContent: AttributedStringContent) {
        self.textContent = textContent
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let scrollView = TextView<AttributedStringContent>.scrollableTextView()
        let textView = scrollView.documentView as! TextView<AttributedStringContent>
        textView.textContent = textContent

        view = scrollView
    }
}
