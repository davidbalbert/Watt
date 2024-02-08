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

    static let didRestoreOpenDocument = Notification.Name("WorkspaceWindowController.didRestoreOpenDocument")

    weak var workspaceDocument: WorkspaceFolderDocument?
    let workspace: Workspace

    // This was @WindowLoading, but for some unknown reason, likely to do with the hacky
    // stuff we do with only sometimes making windows for new documents, that caused
    // loadWindow() to be called a second time when clicking on a Dirent in the sidebar.
    var workspaceViewController: WorkspaceViewController!

    var closeTarget: AnyObject?
    var closeAction: Selector?

    var documentPaneViewController: DocumentPaneViewController {
        workspaceViewController.documentPaneViewController
    }

    var documentViewControllers: [DocumentViewController] {
        if let controller = documentPaneViewController.documentViewController {
            [controller]
        } else {
            []
        }
    }

    var focusedDocumentViewController: DocumentViewController? {
        documentViewControllers.first
    }


    var _selectedURLs: [URL]
    var selectedURLs: [URL] {
        get { _selectedURLs }
        set {
            _selectedURLs = newValue
            if _selectedURLs.count == 1 {
                let url = _selectedURLs[0]
                Task {
                    await openDocument(url)
                }
            }
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
            Task {
                let success = await openDocument(openDocumentURL)
                if success {
                    NotificationCenter.default.post(name: WorkspaceWindowController.didRestoreOpenDocument, object: self)
                    _selectedURLs = [openDocumentURL]
                }
            }
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
        let window = Window(contentViewController: workspaceViewController)

        self.workspaceViewController = workspaceViewController
        self.window = window

        cascade()
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        guard let window else {
            return
        }

        window.identifier = NSUserInterfaceItemIdentifier("WorkspaceWindow \(UUID())")
        window.titlebarSeparatorStyle = .line
        window.delegate = self

        let closeButton = window.standardWindowButton(.closeButton)
        closeTarget = closeButton?.target
        closeAction = closeButton?.action
        closeButton?.target = self
        closeButton?.action = #selector(closeWindow(_:))
    }

    @IBAction func closeWindow(_ sender: Any?) {
        print("WorkspaceWindowController.closeWindow")
        guard let closeAction = closeAction else {
            return
        }

        // Make sure document == workspaceDocument before the window closes
        // so that WorkspaceFolderDocument's shouldCloseWindowController is
        // called to clean up all our tabs, not just the active one.
        workspaceDocument?.addWindowController(self)

        // Don't leak NSOutlineView expanded state. We don't want UserDefaults to contain the
        // expanded state of every Workspace window that's ever been opened.
        UserDefaults.standard.removeObject(forKey: "NSOutlineView Items WorkspaceBrowserOutlineView \(window!.identifier!.rawValue)")

        NSApp.sendAction(closeAction, to: closeTarget, from: sender)
    }

    @IBAction func closeTab(_ sender: Any?) {
        print("WorkspaceWindowController.closeTab")
        assert(document != nil && workspaceDocument != nil)

        if (document as? WorkspaceFolderDocument) == workspaceDocument {
            assert(documentViewControllers.count == 0)
            closeWindow(sender)
            return
        }

        guard let document = document as? Document else {
            assertionFailure("We should always have a document")
            return
        }

        Task {
            await closeDocument(document)
        }
    }

    @discardableResult
    func openDocument(_ url: URL) async -> Bool {
        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        let isFolder = (resourceValues?.isDirectory ?? false) && !(resourceValues?.isPackage ?? false)
        if isFolder {
            return false
        }

        if let doc = DocumentController.shared.document(for: url) as? Document {
            return await openDocument(doc)
        }

        do {
            let (doc, _) = try await DocumentController.shared.openDocument(withContentsOf: url, display: false)
            if let doc = doc as? Document {
                return await openDocument(doc)
            }
        } catch {
            presentError(error, modalFor: window!, delegate: nil, didPresent: nil, contextInfo: nil)
        }
        return false
    }

    func openDocument(_ document: Document) async -> Bool {
        if documentViewControllers.contains(where: { $0.document == document }) {
            return true
        }

        if let focusedDocument = focusedDocumentViewController?.document {
            let didClose = await closeDocument(focusedDocument)
            if !didClose {
                return false
            }
        }

        documentPaneViewController.document = document
        document.addWindowController(self)
        return true
    }

    @discardableResult
    func closeDocument(_ document: Document) async -> Bool {
        guard let workspaceDocument else {
            assertionFailure("We should always have a workspace document")
            return false
        }

        guard let focusedDocumentViewController else {
            assertionFailure("We should always have a focused view controller")
            return false
        }

        assert(document == focusedDocumentViewController.document)

        if await !document.shouldCloseDocumentViewController(focusedDocumentViewController) {
            return false
        }

        document.removeDocumentViewController(focusedDocumentViewController)
        // TODO: this is a hack. Make it better when we add tabs
        documentPaneViewController.document = nil
        workspaceDocument.addWindowController(self)

        if document.documentViewControllers.count == 0 {
            document.close()
        }

        return true
    }
}

extension WorkspaceWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        print("WorkspaceWindowController.windowWillClose")
        for controller in documentViewControllers {
            guard let document = controller.document else {
                continue
            }

            // The window is closing, so I don't think we need to remove
            // the view controller and it's view from the hierarchy.
            document.removeDocumentViewController(controller)
            if document.documentViewControllers.count == 0 {
                document.close()
            }
        }
    }
}
