//
//  WorkspaceWindowController.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa

class WorkspaceWindowController: NSWindowController {
    let workspace: Workspace
    // TODO: I think each FileDocument should be a weak reference? What is Jesse doing here?
    var documents: [FileDocument]

    init(workspace: Workspace) {
        self.workspace = workspace
        self.documents = []
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
        let window = NSWindow(contentViewController: workspaceViewController)
        window.titlebarSeparatorStyle = .line
        
        self.window = window
    }
}
