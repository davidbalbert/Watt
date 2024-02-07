//
//  DocumentPaneViewController.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa

class DocumentPaneViewController: ContainerViewController {
    let workspace: Workspace
    weak var document: Document? {
        didSet {
            if let document {
                let documentViewController = document.makeDocumentViewController()
                document.addDocumentViewController(documentViewController)
                self.documentViewController = documentViewController
            } else {
                documentViewController = nil
            }
        }
    }

    var documentViewController: DocumentViewController? {
        get { containedViewController as? DocumentViewController  }
        set { containedViewController = newValue }
    }

    init(workspace: Workspace, document: Document? = nil) {
        self.workspace = workspace
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
