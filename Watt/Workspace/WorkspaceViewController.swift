//
//  WorkspaceViewController.swift
//  Watt
//
//  Created by David Albert on 1/4/24.
//

import Cocoa
import SwiftUI

class WorkspaceViewController: NSSplitViewController {
    @ViewLoading var workspaceBrowserViewController: WorkspaceBrowserViewController
    @ViewLoading var textViewController: TextDocumentViewController

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
        workspaceBrowserViewController = WorkspaceBrowserViewController(workspace: workspace)
        textViewController = TextDocumentViewController(buffer: Buffer())
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: workspaceBrowserViewController)
        sidebarItem.isSpringLoaded = false

        let textItem = NSSplitViewItem(viewController: textViewController)

        view.frame.size = CGSize(width: 800, height: 600)
        workspaceBrowserViewController.view.frame.size.width = 250

        addSplitViewItem(sidebarItem)
        addSplitViewItem(textItem)
    }
}
