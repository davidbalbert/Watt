//
//  TextDocumentWindowController.swift
//  Watt
//
//  Created by David Albert on 2/1/24.
//

import Cocoa

// A window controller for a standalone (i.e. not in a workspace) TextDocument
class TextDocumentWindowController: WindowController {
    let buffer: Buffer

    init(buffer: Buffer) {
        self.buffer = buffer
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        self.buffer = Buffer()
        super.init(coder: coder)
    }

    // returning non-nil nib name triggers loadWindow()
    override var windowNibName: NSNib.Name? {
        ""
    }

    override func loadWindow() {
        let viewController = TextDocumentViewController(buffer: buffer)
        viewController.view.frame.size = CGSize(width: 800, height: 600)
        
        let window = Window(contentViewController: viewController)
        self.window = window

        cascade()
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        guard let window else {
            return
        }

        window.identifier = NSUserInterfaceItemIdentifier("TextDocumentWindow")
    }

    @IBAction func closeWindow(_ sender: Any?) {
        print("TextDocumentWindowController.closeWindow")
        NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: sender)
    }

    @IBAction func closeTab(_ sender: Any?) {
        print("TextDocumentWindowController.closeTab")
        NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: sender)
    }
}
