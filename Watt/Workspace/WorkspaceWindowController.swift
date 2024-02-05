//
//  WorkspaceWindowController.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa

class WorkspaceWindowController: WindowController {
    enum RestorationKeys {
        static let selectedURLs = "selectedURLs"
        static let openDocumentURL = "openDocumentURL"
    }

    weak var workspaceDocument: WorkspaceFolderDocument?
    let workspace: Workspace

    // This was @WindowLoading, but for some unknown reason, likely to do with the hacky
    // stuff we do with only sometimes making windows for new documents, that caused
    // loadWindow() to be called a second time when clicking on a Dirent in the sidebar.
    var workspaceViewController: WorkspaceViewController!

    var documentPaneViewController: DocumentPaneViewController {
        workspaceViewController.documentPaneViewController
    }

    override var document: AnyObject? {
        didSet {
            if let doc = document as? Document {
                documentPaneViewController.document = doc
            }
        }
    }

    var _selectedURLs: [URL]
    var selectedURLs: [URL] {
        get { _selectedURLs }
        set {
            _selectedURLs = newValue
            updateDocument()
        }
    }

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(workspaceDocument?.fileURL, forKey: DocumentController.RestorationKeys.substituteDocumentURL)
        coder.encode(selectedURLs, forKey: RestorationKeys.selectedURLs)

        if let document, let documentURL = document.fileURL, documentURL != workspaceDocument?.fileURL {
            coder.encode(documentURL, forKey: RestorationKeys.openDocumentURL)
        }
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)

        _selectedURLs = coder.decodeArrayOfObjects(ofClass: NSURL.self, forKey: RestorationKeys.selectedURLs) as? [URL] ?? []

        if let openDocumentURL = coder.decodeObject(of: NSURL.self, forKey: RestorationKeys.openDocumentURL) as? URL {
            openDocument(openDocumentURL)
        }
    }

    init(workspaceDocument: WorkspaceFolderDocument) {
        self.workspaceDocument = workspaceDocument
        self.workspace = workspaceDocument.workspace
        self._selectedURLs = []
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

    func updateDocument() {
        if selectedURLs.count != 1 {
            return
        }
        openDocument(selectedURLs[0])
    }

    func openDocument(_ url: URL) {
        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        let isFolder = (resourceValues?.isDirectory ?? false) && !(resourceValues?.isPackage ?? false)
        if isFolder {
            return
        }

        if let doc = DocumentController.shared.document(for: url) as? Document {
            doc.addWindowController(self)
            return
        }

        Task {
            do {
                let (doc, _) = try await DocumentController.shared.openDocument(withContentsOf: url, display: false)
                if let doc = doc as? Document {
                    doc.addWindowController(self)
                }
            } catch {
                presentError(error, modalFor: window!, delegate: nil, didPresent: nil, contextInfo: nil)
            }
        }
    }
}
