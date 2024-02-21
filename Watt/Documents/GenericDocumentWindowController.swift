//
//  GenericDocumentWindowController.swift
//  Watt
//
//  Created by David Albert on 2/9/24.
//

import Cocoa
import os

class GenericDocumentWindowController: WindowController {
    let url: URL

    init(url: URL) {
        self.url = url
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
        let viewController = GenericDocumentViewController(url: url)
        viewController.view.frame.size = NSSize(width: 800, height: 600)

        let window = Window(contentViewController: viewController)
        self.window = window

        cascade()
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        guard let window else {
            return
        }

        window.contentMinSize = NSSize(width: 300, height: 300)
        window.identifier = NSUserInterfaceItemIdentifier("GenericDocumentWindow")
    }

    @IBAction func closeWindow(_ sender: Any?) {
        Logger.documentLog.debug("GenericDocumentWindowController.closeWindow")
        NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: sender)
    }

    @IBAction func closeTab(_ sender: Any?) {
        Logger.documentLog.debug("GenericDocumentWindowController.closeTab")
        NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: sender)
    }
}
