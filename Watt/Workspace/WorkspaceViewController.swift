//
//  WorkspaceViewController.swift
//  Watt
//
//  Created by David Albert on 1/4/24.
//

import Cocoa
import SwiftUI

class WorkspaceViewController: NSSplitViewController {
    @ViewLoading var browserViewController: WorkspaceBrowserViewController
    @ViewLoading var documentPaneViewController: DocumentPaneViewController

    let workspace: Workspace

    init(workspace: Workspace) {
        self.workspace = workspace
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        browserViewController = WorkspaceBrowserViewController(workspace: workspace)
        documentPaneViewController = DocumentPaneViewController(workspace: workspace)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.frame.size = CGSize(width: 800, height: 600)
        browserViewController.view.frame.size.width = 250

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: browserViewController)
        sidebarItem.isSpringLoaded = false

        let documentItem = NSSplitViewItem(viewController: documentPaneViewController)

        addSplitViewItem(sidebarItem)
        addSplitViewItem(documentItem)
    }
}
