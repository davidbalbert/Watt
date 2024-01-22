//
//  WorkspaceBrowserViewController.swift
//  Watt
//
//  Created by David Albert on 1/9/24.
//

import Cocoa

class WorkspaceBrowserViewController: NSViewController {
    let workspace: Workspace

    @ViewLoading var outlineView: NSOutlineView
    @ViewLoading var dataSource: OutlineViewDiffableDataSource<[Dirent]>

    var task: Task<(), Never>?

    let fileQueue: OperationQueue = OperationQueue()

    init(workspace: Workspace) {
        self.workspace = workspace
        super.init(nibName: nil, bundle: nil)
        workspace.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let outlineView = NSOutlineView()
        outlineView.headerView = nil

        let column = NSTableColumn(identifier: .init("Name"))
        column.title = "Name"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.autoresizesOutlineColumn = false

        let dataSource = OutlineViewDiffableDataSource<[Dirent]>(outlineView) { [weak self] outlineView, column, dirent in
            guard let self else {
                return NSView()
            }

            let view: NSTableCellView
            if let v = outlineView.makeView(withIdentifier: column.identifier, owner: nil) as? NSTableCellView {
                view = v
            } else {
                view = NSTableCellView()
                view.identifier = column.identifier

                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false

                let textField = WorkspaceTextField(labelWithString: "")
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.isEditable = true
                textField.focusRingType = .none
                textField.lineBreakMode = .byTruncatingMiddle
                textField.cell?.sendsActionOnEndEditing = true

                textField.delegate = self

                textField.target = self
                textField.action = #selector(WorkspaceBrowserViewController.onSubmit(_:))

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

            view.imageView!.image = dirent.icon
            view.textField!.stringValue = dirent.name

            return view
        }

        let workspace = workspace
        dataSource.loadChildren = { dirent in
            if dirent.isLoaded {
                return nil
            }

            do {
                try workspace.loadDirectory(url: dirent.url)
            } catch {
                print("dataSource.loadChildren: error while loading \(dirent.url): \(error)")
            }
            return OutlineViewSnapshot(workspace.children, children: \.children)
        }

        dataSource.dragAndDropDelegate = self
        outlineView.setDraggingSourceOperationMask(.copy, forLocal: false)
        outlineView.registerForDraggedTypes(
            NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        )
        outlineView.registerForDraggedTypes([
            .fileURL
        ])

        self.outlineView = outlineView
        self.dataSource = dataSource

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = outlineView

        view = scrollView
    }

    override func viewDidLoad() {
        updateView()
    }

    override func viewWillAppear() {
        task = Task.detached(priority: .medium) { [weak self] in
            await self?.workspace.listen()
        }
    }

    override func viewWillDisappear() {
        task?.cancel()
    }

    func updateView() {
        let snapshot = OutlineViewSnapshot(workspace.children, children: \.children)
        dataSource.apply(snapshot, animatingDifferences: UserDefaults.standard.workspaceBrowserAnimationsEnabled && !dataSource.isEmpty)
    }

    @objc func onSubmit(_ sender: WorkspaceTextField) {
        print("onSubmit", sender)
        guard let dirent = dirent(for: sender) else {
            return
        }
        do {
            let newDirent = try workspace.rename(dirent, to: sender.stringValue)
            sender.stringValue = newDirent.name
        } catch {
            sender.stringValue = dirent.name
            presentErrorAsSheetWithFallback(error)
        }
    }

    @objc func onCancel(_ sender: WorkspaceTextField) {
        print("onCancel", sender)
        guard let dirent = dirent(for: sender) else {
            return
        }

        sender.stringValue = dirent.name
    }

    func dirent(for textField: WorkspaceTextField) -> Dirent? {
        dataSource[(textField.superview as? NSTableCellView)?.objectValue as! Dirent.ID]
    }
}

extension WorkspaceBrowserViewController: WorkspaceDelegate {
    func workspaceDidChange(_ workspace: Workspace) {
        updateView()
    }
}

extension WorkspaceBrowserViewController: WorkspaceTextFieldDelegate {
    func textFieldDidBecomeFirstResponder(_ textField: WorkspaceTextField) {
        guard let dirent = dirent(for: textField) else {
            return
        }

        let s = dirent.nameWithExtension
        textField.stringValue = s
        let range = s.startIndex..<(s.firstIndex(of: ".") ?? s.endIndex)
        textField.currentEditor()?.selectedRange = NSRange(range, in: s)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard let textField = control as? WorkspaceTextField else {
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
