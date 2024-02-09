//
//  Window.swift
//  Watt
//
//  Created by David Albert on 2/5/24.
//

import Cocoa
import os

class Window: NSWindow {
    override func performClose(_ sender: Any?) {
        Logger.documentLog.debug("Window.performClose")
        super.performClose(sender)
    }

    override func close() {
        Logger.documentLog.debug("Window.close")
        super.close()
    }
}
