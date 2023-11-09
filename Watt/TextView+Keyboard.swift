//
//  TextView+Keyboard.swift
//  Watt
//
//  Created by David Albert on 11/9/23.
//

import Cocoa

extension TextView {
    override func keyDown(with event: NSEvent) {
        NSCursor.setHiddenUntilMouseMoves(true)

        if inputContext?.handleEvent(event) ?? false {
            return
        }

        // Don't know if handleEvent ever returns false here. Just want to know about it.
        fatalError("keyDown: inputContext didn't handle this event: \(event)")
    }
}
