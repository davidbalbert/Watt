//
//  TextView+Events.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa

extension TextView {
    // MARK: - First responder
    override var acceptsFirstResponder: Bool {
        true
    }

    override var canBecomeKeyView: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        // setSelectionNeedsDisplay() // TODO
        updateInsertionPointTimer()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        // setSelectionNeedsDisplay() // TODO
        updateInsertionPointTimer()
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        NSCursor.setHiddenUntilMouseMoves(true)

        if inputContext?.handleEvent(event) ?? false {
            return
        }

        // Don't know if handleEvent ever returns false here. Just want to know about it.
        assert(false, "keyDown: inputContext didn't handle this event: \(event)")
    }

    // MARK: - Mouse events
    override func mouseDown(with event: NSEvent) {
        if inputContext?.handleEvent(event) ?? false {
            return
        }

        let locationInView = convert(event.locationInWindow, from: nil)
        let point = convertToTextContainer(locationInView)
        startSelection(at: point)
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func mouseDragged(with event: NSEvent) {
        if inputContext?.handleEvent(event) ?? false {
            return
        }

        let locationInView = convert(event.locationInWindow, from: nil)
        let point = convertToTextContainer(locationInView)
        extendSelection(to: point)
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func mouseUp(with event: NSEvent) {
        inputContext?.handleEvent(event)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.iBeam.set()
    }
}
