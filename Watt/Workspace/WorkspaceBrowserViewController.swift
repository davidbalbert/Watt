//
//  WorkspaceBrowserViewController.swift
//  Watt
//
//  Created by David Albert on 1/9/24.
//

import Cocoa
import SwiftUI

struct DirentView: View {
    let dirent: Dirent

    var body: some View {
        HStack {
            Image(nsImage: dirent.icon)
                .resizable()
                .frame(width: 16, height: 16)

            Text(dirent.name)
                .lineLimit(1)
        }
        .listRowSeparator(.hidden)
    }
}

class WorkspaceBrowserViewController: NSViewController {
    let workspace: Workspace

    @ViewLoading var outlineView: NSOutlineView
    @ViewLoading var dataSource: OutlineViewDiffableDataSource<[Dirent]>

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

        let dataSource = OutlineViewDiffableDataSource<[Dirent]>(outlineView) { _, _, dirent in
            HStack {
                DirentView(dirent: dirent)
                Spacer()
            }
        }

        dataSource.loadChildren = { [weak self] dirent in
            guard let self else { return nil }

            if dirent.isLoaded {
                return nil
            }

            workspace.loadDirectory(url: dirent.url, highPriority: true)
            return OutlineViewSnapshot(workspace.root.children!, children: \.children)
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

    func updateView() {
        let snapshot = OutlineViewSnapshot(workspace.root.children!, children: \.children)
        dataSource.apply(snapshot, animatingDifferences: !dataSource.isEmpty)
   }
}

extension WorkspaceBrowserViewController: WorkspaceDelegate {
    func workspaceDidChange(_ workspace: Workspace) {
        updateView()
    }
}
