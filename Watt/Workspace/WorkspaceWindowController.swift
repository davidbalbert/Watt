//
//  WorkspaceWindowController.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa

class WorkspaceWindowController: WindowController {
    let workspace: Workspace

    // This was @WindowLoading, but for some unknown reason, likely to do with the hacky
    // stuff we do with only sometimes making windows for new documents, that caused
    // loadWindow() to be called a second time when clicking on a Dirent in the sidebar.
    var workspaceViewController: WorkspaceViewController!

    var documentPaneViewController: DocumentPaneViewController {
        workspaceViewController.documentPaneViewController
    }

    weak var activeDocument: Document? {
        didSet {
            documentPaneViewController.document = activeDocument
        }
    }

    var selectedDirents: [Dirent] {
        didSet {
            updateActiveDocument()
        }
    }

    init(workspace: Workspace) {
        self.workspace = workspace
        self.activeDocument = nil
        self.selectedDirents = []
        super.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // returning non-nil nib name triggers loadWindow()
    override var windowNibName: NSNib.Name? {
        ""
    }

    override func loadWindow() {
        let workspaceViewController = WorkspaceViewController(workspace: workspace)
        let window = NSWindow(contentViewController: workspaceViewController)
        window.tabbingIdentifier = "WorkspaceWindow"
        window.titlebarSeparatorStyle = .line

        self.workspaceViewController = workspaceViewController
        self.window = window

        cascade()
    }

    func updateActiveDocument() {
        if selectedDirents.count != 1 {
            return
        }

        let dirent = selectedDirents[0]
        if dirent.isFolder {
            return
        }

        if let doc = DocumentController.shared.document(for: dirent.url) as? Document {
            activeDocument = doc
            return
        }

        Task {
            do {
                let (doc, _) = try await DocumentController.shared.openDocument(withContentsOf: dirent.url, display: false)
                if let doc = doc as? Document {
                    activeDocument = doc
                }
            } catch {
                presentError(error, modalFor: window!, delegate: nil, didPresent: nil, contextInfo: nil)
            }
        }
    }
}
