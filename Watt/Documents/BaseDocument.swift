//
//  BaseDocument.swift
//  Watt
//
//  Created by David Albert on 2/7/24.
//

import Cocoa
import os

extension Logger {
    static let documentLog = Logger(type: BaseDocument.self).enabled(false)
}

class BaseDocument: NSDocument {
    override func close() {
        Logger.documentLog.debug("\(self.className).close")
        super.close()
    }

    override func addWindowController(_ windowController: NSWindowController) {
        Logger.documentLog.debug("\(self.className).addWindowController")
        super.addWindowController(windowController)
    }

    override func removeWindowController(_ windowController: NSWindowController) {
        Logger.documentLog.debug("\(self.className).removeWindowController")
        super.removeWindowController(windowController)
    }
}
