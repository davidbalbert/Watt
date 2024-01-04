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

        let browserVC = NSHostingController(rootView: WorkspaceBrowser(project: Project(url: URL(filePath: "/Users/david/Developer/Watt/Watt"))!))
        let textVC = TextViewController(buffer)

        let browserItem = NSSplitViewItem(contentListWithViewController: browserVC)
        let textItem = NSSplitViewItem(viewController: textVC)

        addSplitViewItem(browserItem)
        addSplitViewItem(textItem)
    }
}