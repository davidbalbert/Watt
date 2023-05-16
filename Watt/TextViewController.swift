//
//  DocumentViewController.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextViewController: NSViewController {
    var contentManager: AttributedStringContentManager

    init(_ textContent: AttributedStringContentManager) {
        self.contentManager = textContent
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let scrollView = TextView<AttributedStringContentManager>.scrollableTextView()
        let textView = scrollView.documentView as! TextView<AttributedStringContentManager>
        textView.contentManager = contentManager

        view = scrollView
    }
}
