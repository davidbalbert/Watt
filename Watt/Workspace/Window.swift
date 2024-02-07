//
//  Window.swift
//  Watt
//
//  Created by David Albert on 2/5/24.
//

import Cocoa

class Window: NSWindow {
    override func performClose(_ sender: Any?) {
        print("Window.performClose")
        super.performClose(sender)
    }

    override func close() {
        print("Window.close")
        super.close()
    }
}
