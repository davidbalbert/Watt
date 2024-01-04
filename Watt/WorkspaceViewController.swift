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

    init(buffer: Buffer) {
        self.buffer = buffer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let browserVC = NSHostingController(rootView: WorkspaceBrowser(workspace: Workspace(url: URL(filePath: "/Users/david/Developer/Watt"))!))
        let textVC = TextViewController(buffer)

        let browserItem = NSSplitViewItem(sidebarWithViewController: browserVC)
        let textItem = NSSplitViewItem(viewController: textVC)

        addSplitViewItem(browserItem)
        addSplitViewItem(textItem)

        splitView.setPosition(275, ofDividerAt: 0)
    }
}
