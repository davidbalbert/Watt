//
//  DocumentPaneViewController.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa

class DocumentPaneViewController: ContainerViewController {
    let workspace: Workspace
    weak var document: FileDocument?

    init(workspace: Workspace, document: FileDocument? = nil) {
        self.workspace = workspace
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
