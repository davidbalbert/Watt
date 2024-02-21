//
//  WindowController.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa
import os

class WindowController: NSWindowController {
    func cascade() {
        guard let window else {
            return
        }

        // TODO:
        // - If the window is the full size of the screen, don't cascade, just make it the same size
        //   in the same place.
        // - Possibly different behavior based on whether we're a workspace window or a text window.
        if let point = NSApp.mainWindow?.cascadeTopLeft(from: .zero) {
            window.cascadeTopLeft(from: point)
        } else {
            window.center()
        }
    }

    override func close() {
        Logger.documentLog.debug("\(self.className).close")
        super.close()
    }
}
