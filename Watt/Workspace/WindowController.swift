//
//  WindowController.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Cocoa

class WindowController: NSWindowController {
    func cascade() {
        guard let window else {
            return
        }

        // TODO: If the window is the full size of the screen, don't cascade, just make it the same size
        // in the same place.
        if let mainWindow = NSApp.mainWindow, mainWindow.tabbingIdentifier == window.tabbingIdentifier {
            window.cascadeTopLeft(from: mainWindow.frame.origin)
        } else {
            window.center()
        }
    }
}
