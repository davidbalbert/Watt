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

        let dataSource = OutlineViewDiffableDataSource<[Dirent]>(outlineView) { outlineView, column, dirent in
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
        // TODO: rename file
        // TODO: hide file extension
    }

    @objc func onCancel(_ sender: WorkspaceTextField) {
        print("onCancel", sender)
        // TODO: hide file extension
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

        textField.stringValue = dirent.nameWithExtension
        // TODO: select dirent.name
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard let textField = control as? WorkspaceTextField else {
            return false
        }

        switch commandSelector {
        case #selector(cancelOperation):
            onCancel(textField)
        default:
            break
        }

        return false
    }

    func dirent(for textField: NSTextField) -> Dirent? {
        dataSource[(textField.superview as? NSTableCellView)?.objectValue]
    }
}
