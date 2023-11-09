//
//  TextView+Mouse.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa
import StandardKeyBindingResponder

extension TextView {
    override func mouseDown(with event: NSEvent) {
        if inputContext?.handleEvent(event) ?? false {
            return
        }

        discardMarkedText()

        let locationInView = convert(event.locationInWindow, from: nil)
        let point = convertToTextContainer(locationInView)

        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .shift {
            layoutManager.selection = SelectionNavigator(selection: selection).extendSelection(interactingAt: point, dataSource: layoutManager)
        } else {
            layoutManager.selection = SelectionNavigator.selection(interactingAt: point, dataSource: layoutManager)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if inputContext?.handleEvent(event) ?? false {
            return
        }

        let locationInView = convert(event.locationInWindow, from: nil)
        let point = convertToTextContainer(locationInView)
        layoutManager.selection = SelectionNavigator(selection: selection).extendSelection(interactingAt: point, dataSource: layoutManager)
    }

    override func mouseUp(with event: NSEvent) {
        inputContext?.handleEvent(event)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.iBeam.set()
    }
}
