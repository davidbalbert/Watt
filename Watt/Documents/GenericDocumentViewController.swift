//
//  GenericDocumentViewController.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa
import QuickLookUI

class GenericDocumentViewController: DocumentViewController {
    @ViewLoading var quickLookView: QLPreviewView

    let url: URL

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()

        quickLookView = QLPreviewView()
        quickLookView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(quickLookView)

        view.addConstraints([
            quickLookView.topAnchor.constraint(equalTo: view.topAnchor),
            quickLookView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            quickLookView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            quickLookView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateViews()
    }

    func updateViews() {
        quickLookView.previewItem = url as QLPreviewItem
        quickLookView.refreshPreviewItem()
    }
}
