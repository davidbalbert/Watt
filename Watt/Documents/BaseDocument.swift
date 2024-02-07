//
//  BaseDocument.swift
//  Watt
//
//  Created by David Albert on 2/7/24.
//

import Cocoa

class BaseDocument: NSDocument {
    override func close() {
        Swift.print("\(className).close")
        super.close()
    }

    override func addWindowController(_ windowController: NSWindowController) {
        Swift.print("\(className).addWindowController")
        super.addWindowController(windowController)
    }

    override func removeWindowController(_ windowController: NSWindowController) {
        Swift.print("\(className).removeWindowController")
        super.removeWindowController(windowController)
    }
}
