//
//  WorkspaceViewController.swift
//  Watt
//
//  Created by David Albert on 1/4/24.
//

import Cocoa
import SwiftUI

class WorkspaceViewController: NSSplitViewController {
    var buffer: Buffer
    var workspace: Workspace = Workspace(url: URL(filePath: "/Users/david/Developer/Watt"))

    var task: Task<(), Never>?

    init(buffer: Buffer) {
        self.buffer = buffer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        buffer = Buffer()
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let browserVC = NSHostingController(rootView: WorkspaceBrowser(workspace: workspace))
        let textVC = TextViewController(buffer)

        let browserItem = NSSplitViewItem(sidebarWithViewController: browserVC)
        let textItem = NSSplitViewItem(viewController: textVC)

        addSplitViewItem(browserItem)
        addSplitViewItem(textItem)

        splitView.setPosition(275, ofDividerAt: 0)
    }

    override func viewWillAppear() {
        task = Task {
            await workspace.watchForChanges()
        }
    }

    override func viewWillDisappear() {
        task?.cancel()
    }
}
