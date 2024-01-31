//
//  WorkspaceViewController.swift
//  Watt
//
//  Created by David Albert on 1/4/24.
//

import Cocoa
import SwiftUI

class WorkspaceViewController: NSSplitViewController {
    @ViewLoading var sidebarViewController: ContainerViewController
    @ViewLoading var textViewController: TextViewController

    var sidebarObserver: NSKeyValueObservation?

    var buffer: Buffer
    var workspace: Workspace? {
        didSet {
            updateSidebar()
        }
    }

    init(buffer: Buffer) {
        self.buffer = buffer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        buffer = Buffer()
        super.init(coder: coder)
    }

    override func loadView() {
        super.loadView()
        sidebarViewController = ContainerViewController()
        textViewController = TextViewController(buffer)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateSidebar()
        sidebarViewController.view.frame.size.width = 200

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.isSpringLoaded = false

        sidebarObserver = sidebarItem.observe(\.isCollapsed) { [weak self] item, _ in
            if item.isCollapsed {
                self?.view.window?.titlebarSeparatorStyle = .automatic
            } else {
                self?.view.window?.titlebarSeparatorStyle = .line
            }
        }

        let textItem = NSSplitViewItem(viewController: textViewController)

        addSplitViewItem(sidebarItem)
        addSplitViewItem(textItem)
    }

    func updateSidebar() {
        if let workspace {
            sidebarViewController.containedViewController = WorkspaceBrowserViewController(workspace: workspace)
        } else {
            sidebarViewController.containedViewController = EmptyWorkspaceViewController()
        }
    }
}
