//
//  WorkspaceBrowserViewController.swift
//  Watt
//
//  Created by David Albert on 1/9/24.
//

import Cocoa
import SwiftUI

class WorkspaceBrowserViewController: NSViewController {
    let workspace: Workspace

    @ViewLoading var outlineView: NSOutlineView
    @ViewLoading var dataSource: OutlineViewDiffableDataSource<[Dirent]>

    init(workspace: Workspace) {
        self.workspace = workspace
        super.init(nibName: nil, bundle: nil)
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

            workspace.fetchChildren(url: dirent.url)
            return OutlineViewSnapshot(workspace.root.children!, children: \.children)
        }

        self.outlineView = outlineView
        self.dataSource = dataSource

        let scrollView = NSScrollView()
        scrollView.documentView = outlineView

        view = scrollView
    }

    override func viewDidLoad() {
        updateView()
    }

    func updateView() {
        let snapshot = OutlineViewSnapshot(workspace.root.children!, children: \.children)
        dataSource.apply(snapshot)
    }
}
