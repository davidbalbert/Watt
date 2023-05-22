//
//  TextView+Events.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

extension TextView {
    override func mouseDown(with event: NSEvent) {
        if inputContext?.handleEvent(event) ?? false {
            return
        }

        let locationInView = convert(event.locationInWindow, from: nil)
        let point = convertToTextContainer(locationInView)
        startSelection(at: point)
        selectionLayer.setNeedsLayout()
        caretLayer.setNeedsLayout()
    }

    override func mouseDragged(with event: NSEvent) {
        if inputContext?.handleEvent(event) ?? false {
            return
        }

        let locationInView = convert(event.locationInWindow, from: nil)
        let point = convertToTextContainer(locationInView)
        extendSelection(to: point)
        selectionLayer.setNeedsLayout()
        caretLayer.setNeedsLayout()
    }

    override func mouseUp(with event: NSEvent) {
        inputContext?.handleEvent(event)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.iBeam.set()
    }
}
