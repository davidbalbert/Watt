//
//  WorkspaceViewController.swift
//  Watt
//
//  Created by David Albert on 1/9/24.
//

import Cocoa

class WorkspaceBrowserViewController: NSViewController {
    enum Errors: Error, LocalizedError {
        case invalidDirentID
        case noDirentInWorkspace(Dirent.ID)

        var errorDescription: String? {
            switch self {
            case .invalidDirentID:
                String(localized: "Invalid Dirent ID")
            case let .noDirentInWorkspace(id):
                String(localized: "Unable to find Dirent with ID \(String(describing: id)) in workspace.")
            }
        }

        var failureReason: String? {
            String(localized: "This is a bug in Watt. Please report it.")
        }
    }

    let workspace: Workspace

    @ViewLoading var outlineView: NSOutlineView
    @ViewLoading var dataSource: OutlineViewDiffableDataSource<[Dirent]>

    private var task: Task<(), Never>?
    private var skipWorkspaceDidChange = false

    // We need to update selectedURLs on both selectionDidChange and rowClicked, but not both.
    // In situations where they're both fired, selectionDidChange fires first.
    private var didUpdateURLs = false

    let filePromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "NSFilePromiseProvider queue"
        queue.qualityOfService = .userInitiated
        return queue
    }()

    var workspaceWindowController: WorkspaceWindowController? {
        view.window?.windowController as? WorkspaceWindowController
    }

    init(workspace: Workspace) {
        self.workspace = workspace
        super.init(nibName: nil, bundle: nil)
        workspace.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()

        let outlineView = NSOutlineView()
        outlineView.headerView = nil

        let column = NSTableColumn(identifier: .init("Name"))
        column.title = "Name"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.autoresizesOutlineColumn = false
        outlineView.allowsMultipleSelection = true
        outlineView.autosaveExpandedItems = true
        outlineView.target = self
        outlineView.action = #selector(rowClicked(_:))

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = outlineView

        view.addSubview(scrollView)

        view.addConstraints([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let workspace = self.workspace

        let dataSource = OutlineViewDiffableDataSource<[Dirent]>(outlineView, delegate: self) { [weak self] outlineView, column, dirent in
            guard let self else {
                return NSView()
            }

            let view = makeTableCellView(for: column, isEditable: true)
            view.imageView!.image = dirent.icon
            view.textField!.stringValue = dirent.name

            return view
        }

        dataSource.loadChildren = { [weak self] dirent in
            if dirent.isLoaded {
                return nil
            }

            do {
                try workspace.loadDirectory(url: dirent.url)
            } catch {
                self?.presentErrorAsSheet(error)
            }
            return OutlineViewSnapshot(workspace.children, children: \.children)
        }

        outlineView.setDraggingSourceOperationMask([.move, .copy, .generic], forLocal: true)
        outlineView.setDraggingSourceOperationMask([.copy, .delete], forLocal: false)

        dataSource.onDrag = { dirent in
            WorkspacePasteboardWriter(dirent: dirent, delegate: self)
        }

        dataSource.onDragEnd(for: URL.self, operation: .delete, searchOptions: [.urlReadingFileURLsOnly: true]) { [weak self] urls, operation in
            Task {
                do {
                    try await workspace.trash(filesAt: urls)
                } catch {
                    self?.presentErrorAsSheet(error)
                }
            }
        }

        dataSource.validDropTargets = .betweenRows

        dataSource.onDrop(of: NSFilePromiseReceiver.self, operation: .copy, source: .remote) { [weak self] filePromiseReceivers, destination, _ in
            Task {
                do {
                    let targetDirectoryURL = (destination.parent ?? workspace.root).url
                    try await workspace.receive(filesFrom: filePromiseReceivers, atDestination: targetDirectoryURL)
                } catch {
                    self?.presentErrorAsSheet(error)
                }
            }
        }

        dataSource.onDrop(of: URL.self, operations: [.copy, .generic], source: .remote, searchOptions: [.urlReadingFileURLsOnly: true]) { [weak self] srcURLs, destination, operation in
            Task {
                do {
                    let targetDirectoryURL = (destination.parent ?? workspace.root).url
                    let dstURLs = srcURLs.map {
                        targetDirectoryURL.appendingPathComponent($0.lastPathComponent)
                    }

                    if operation == .generic {
                        try await workspace.move(filesAt: srcURLs, to: dstURLs)
                    } else {
                        assert(operation == .copy)
                        try await workspace.copy(filesAt: srcURLs, intoWorkspaceAt: dstURLs)
                    }
                } catch {
                    self?.presentErrorAsSheet(error)
                }
            }
        } preview: { [weak self] url in
            guard let dirent = try? Dirent(for: url), let column = self?.outlineView.outlineTableColumn else {
                return nil
            }

            return self?.dragPreview(for: column, dirent: dirent)
        }

        dataSource.onDrop(of: ReferenceDirent.self, operations: [.move, .generic], source: .self) { [weak self] refs, destination, _ in
            Task {
                do {
                    let oldURLs = refs.map(\.url)
                    let targetDirectoryURL = (destination.parent ?? workspace.root).url
                    let newURLs = oldURLs.map {
                        targetDirectoryURL.appending(path: $0.lastPathComponent)
                    }
                    try await workspace.move(filesAt: oldURLs, to: newURLs)
                } catch {
                    self?.presentErrorAsSheet(error)
                }
            }
        }

        dataSource.onDrop(of: ReferenceDirent.self, operation: .copy, source: .self) { [weak self] refs, destination, _ in
            Task {
                do {
                    let srcURLs = refs.map(\.url)
                    let targetDirectoryURL = (destination.parent ?? workspace.root).url
                    let dstURLs = srcURLs.map {
                        targetDirectoryURL.appending(path: $0.lastPathComponent)
                    }
                    try await workspace.copy(filesAt: srcURLs, intoWorkspaceAt: dstURLs)
                } catch {
                    self?.presentErrorAsSheet(error)
                }
            }
        }

        self.dataSource = dataSource
        self.outlineView = outlineView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateView()

        let workspace = workspace
        task = Task.detached(priority: .medium) {
            await workspace.listen()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // This triggers the autosave state restoration. Must be set after setting the data source
        // and applying the first snapshot (with updateView).
        outlineView.autosaveName = "WorkspaceBrowserOutlineView \(view.window!.identifier!.rawValue)"

        if let workspaceWindowController {
            NotificationCenter.default.addObserver(self, selector: #selector(workspaceDidRestoreOpenDocument(_:)), name: WorkspaceWindowController.didRestoreOpenDocument, object: workspaceWindowController)
        }
    }

    deinit {
        task?.cancel()
    }

    @objc func workspaceDidRestoreOpenDocument(_ notification: Notification) {
        if let focusedURL = workspaceWindowController?.focusedDocumentViewController?.document?.fileURL {
            let dirent = try? Dirent(for: focusedURL)
            if let id = dirent?.id {
                let row = outlineView.row(forItem: id)
                if row != -1 {
                    outlineView.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
                    outlineView.scrollRowToVisible(row)
                }
            }
        }
    }

    func makeTableCellView(for column: NSTableColumn, isEditable: Bool) -> NSTableCellView {
        let view: NSTableCellView
        if let v = outlineView.makeView(withIdentifier: column.identifier, owner: nil) as? NSTableCellView {
            view = v
        } else {
            view = NSTableCellView()
            view.identifier = column.identifier

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false

            let textField = DirentTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.isEditable = isEditable
            textField.focusRingType = .none
            textField.lineBreakMode = .byTruncatingMiddle
            textField.cell?.sendsActionOnEndEditing = true

            textField.delegate = self

            textField.target = self
            textField.action = #selector(WorkspaceBrowserViewController.submit(_:))

            view.addSubview(imageView)
            view.addSubview(textField)
            view.imageView = imageView
            view.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        }

        return view
    }

    func dragPreview(for column: NSTableColumn, dirent: Dirent) -> DragPreview {
        // Drag previews don't show text unless they're not editable. Not sure why.
        let view = makeTableCellView(for: column, isEditable: false)
        view.imageView!.image = dirent.icon
        view.textField!.stringValue = dirent.name

        view.frame.size = NSSize(width: view.fittingSize.width, height: outlineView.rowHeight)
        view.layoutSubtreeIfNeeded()

        return DragPreview(frame: view.frame) {
            return view.draggingImageComponents
        }
    }

    func updateView() {
        let snapshot = OutlineViewSnapshot(workspace.children, children: \.children)
        dataSource.apply(snapshot, animatingDifferences: UserDefaults.standard.workspaceBrowserAnimationsEnabled && !dataSource.isEmpty)
    }

    @objc func rowClicked(_ sender: NSOutlineView) {
        if !didUpdateURLs {
            updateSelectedURLs()
        }
    }

    func updateSelectedURLs() {
        guard let workspaceWindowController else {
            return
        }

        let selectedDirents = outlineView.selectedRowIndexes.compactMap { i -> Dirent? in
            guard let id = outlineView.item(atRow: i) as? Dirent.ID else {
                return nil
            }
            return dataSource[id]
        }

        workspaceWindowController.selectedURLs = selectedDirents.map(\.url)
    }

    @objc func submit(_ sender: DirentTextField) {
        guard let dirent = dirent(for: sender) else {
            return
        }

        if dirent.nameWithExtension == sender.stringValue {
            sender.stringValue = dirent.name
            return
        }

        Task {
            do {
                let oldURL = dirent.url
                let newURL = dirent.url.deletingLastPathComponent().appending(path: sender.stringValue, directoryHint: dirent.directoryHint)

                // skip delegate notifications and call updateView() manually so we can eliminate a flicker when
                // updating the file name and image. This doesn't always work (I don't know why) but it works
                // most of the time.
                var actualURL: URL?
                try await withoutWorkspaceDidChange {
                    actualURL = try await workspace.move(filesAt: [oldURL], to: [newURL]).first
                }

                let dirent = try Dirent(for: actualURL!)
                sender.stringValue = dirent.name
                (sender.superview as! NSTableCellView).imageView!.image = dirent.icon

                updateView()
            } catch {
                sender.stringValue = dirent.name
                presentErrorAsSheet(error)
            }
        }
    }

    @objc func onCancel(_ sender: DirentTextField) {
        guard let dirent = dirent(for: sender) else {
            return
        }

        sender.stringValue = dirent.name
    }

    @objc func delete(_ sender: Any) {
        let indexes = outlineView.selectedRowIndexes
        if indexes.isEmpty {
            // should never happen because of menu validation
            return
        }

        let messageText: String
        let informativeText: String
        if indexes.count == 1 {
            guard let i = indexes.first, let id = outlineView.item(atRow: i) as? Dirent.ID else {
                presentErrorAsSheet(Errors.invalidDirentID)
                return
            }

            guard let dirent = dataSource[id] else {
                presentErrorAsSheet(Errors.noDirentInWorkspace(id))
                return
            }

            var name = dirent.nameWithExtension
            if name.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                name = "\"\(name)\""
            }

            messageText = String(localized: "Are you sure you want to delete \(name)?")
            informativeText = String(localized: "The selected item will be moved to the Trash.")
        } else {
            messageText = String(localized: "Are you sure you want to delete the selected \(indexes.count) items?")
            informativeText = String(localized: "The selected items will be moved to the Trash.")
        }

        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Delete"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        Task {
            let response = await alert.beginSheetModal(for: view.window!)
            guard response == .alertFirstButtonReturn else {
                return
            }

            let ids = indexes.compactMap { outlineView.item(atRow: $0) as? Dirent.ID }
            if ids.count < indexes.count {
                let error = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: nil)
                presentErrorAsSheet(error)
                return
            }

            var urls: [URL] = []
            for id in ids {
                guard let dirent = dataSource[id] else {
                    presentErrorAsSheet(Errors.noDirentInWorkspace(id))
                    return
                }

                urls.append(dirent.url)
            }

            do {
                try await workspace.trash(filesAt: urls)
            } catch {
                presentErrorAsSheet(error)
            }
        }   
    }

    func withoutWorkspaceDidChange(perform block: () async throws -> Void) async throws {
        skipWorkspaceDidChange = true
        defer { skipWorkspaceDidChange = false }
        try await block()
    }

    func dirent(for textField: DirentTextField) -> Dirent? {
        dataSource[(textField.superview as? NSTableCellView)?.objectValue as! Dirent.ID]
    }
}

extension WorkspaceBrowserViewController: NSOutlineViewDelegate {
    func outlineViewSelectionDidChange(_ notification: Notification) {
        didUpdateURLs = true
        updateSelectedURLs()
        Task {
            await Task.yield()
            didUpdateURLs = false
        }
    }
}

extension WorkspaceBrowserViewController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(delete(_:)):
            return !outlineView.selectedRowIndexes.isEmpty
        default:
            return true
        }
    }
}

extension WorkspaceBrowserViewController: WorkspaceDelegate {
    func workspaceDidChange(_ workspace: Workspace) {
        if skipWorkspaceDidChange {
            return
        }
        updateView()
    }
}

extension WorkspaceBrowserViewController: DirentTextFieldDelegate {
    func textFieldDidBecomeFirstResponder(_ textField: DirentTextField) {
        guard let dirent = dirent(for: textField) else {
            return
        }

        let s = dirent.nameWithExtension
        textField.stringValue = s
        let range = s.startIndex..<(s.firstIndex(of: ".") ?? s.endIndex)
        textField.currentEditor()?.selectedRange = NSRange(range, in: s)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard let textField = control as? DirentTextField else {
            return false
        }

        switch commandSelector {
        case #selector(cancelOperation):
            onCancel(textField)
        case #selector(insertTab):
            view.window?.makeFirstResponder(outlineView)
            return true
        case #selector(deleteWordBackward):
            return deleteFileExtensionOrWordBackward(textView)
        default:
            break
        }

        return false
    }

    func deleteFileExtensionOrWordBackward(_ textView: NSTextView) -> Bool {
        if textView.selectedRanges.count != 1 || textView.selectedRange.length > 0 {
            return false
        }

        let s = textView.string

        let caret = s.utf16Index(at: textView.selectedRange.location)
        let target = caret == s.startIndex ? s.startIndex : s.index(before: caret)
        let afterDot = s.range(of: ".", options: .backwards, range: s.startIndex..<target)?.upperBound ?? s.startIndex

        var i: String.Index?
        s.enumerateSubstrings(in: s.startIndex..<caret, options: [.byWords, .reverse, .substringNotRequired]) { _, range, _, stop in
            i = range.lowerBound
            stop = true
        }
        let wordStart = i ?? s.startIndex

        let range = max(wordStart, afterDot)..<caret
        let nsRange = NSRange(range, in: s)

        // don't copy textStorage
        _ = consume s

        if textView.shouldChangeText(in: nsRange, replacementString: "") {
            textView.textStorage?.replaceCharacters(in: nsRange, with: "")
            textView.didChangeText()
        }

        return true
    }
}

extension WorkspaceBrowserViewController: NSFilePromiseProviderDelegate {
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        let provider = filePromiseProvider as! WorkspacePasteboardWriter
        return provider.dirent.url.lastPathComponent
    }

    nonisolated func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo destinationURL: URL, completionHandler: @escaping (Error?) -> Void) {
        let provider = filePromiseProvider as! WorkspacePasteboardWriter

        do {
            let sourceURL = provider.dirent.url

            // The NSFilePromiseProviderDelegate docs are a bit unclear about whether we need
            // to coordinate writing to destinationURL, but when I tried doing that, I hit
            // what looked like a deadlock, so I assume we shouldn't.
            try NSFileCoordinator().coordinate(readingItemAt: sourceURL) { actualSourceURL in
                try FileManager.default.copyItem(at: actualSourceURL, to: destinationURL)
            }
            completionHandler(nil)
        } catch {
            Task { @MainActor in
                self.presentErrorAsSheet(error)
            }
            completionHandler(error)
        }
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        filePromiseQueue
    }
}
