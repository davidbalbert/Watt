//
//  DocumentViewController.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class TextViewController: NSViewController {
    var contentManager: TextStorageContentManager

    init(_ textContent: TextStorageContentManager) {
        self.contentManager = textContent
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let scrollView = TextView<TextStorageContentManager>.scrollableTextView()
        let textView = scrollView.documentView as! TextView<TextStorageContentManager>
        textView.contentManager = contentManager

        view = scrollView
    }
}
