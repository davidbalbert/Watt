//
//  GenericDocumentViewController.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa

class GenericDocumentViewController: DocumentViewController {
    @ViewLoading var imageView: NSImageView
    @ViewLoading var label: NSTextField

    let url: URL

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil    )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()

        imageView = NSImageView()
        label = NSTextField(labelWithString: url.lastPathComponent)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateViews()
    }

    func updateViews() {
        imageView.image = NSWorkspace.shared.icon(forFile: url.path)
        label.stringValue = url.lastPathComponent
    }
}
