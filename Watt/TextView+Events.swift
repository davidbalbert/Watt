//
//  TextView+Events.swift
//  Watt
//
//  Created by David Albert on 5/22/23.
//

import Cocoa
import StandardKeyBindingResponder

extension TextView {
    // MARK: - First responder
    override var acceptsFirstResponder: Bool {
        true
    }

    override var canBecomeKeyView: Bool {
        true
    }

    var isFirstResponder: Bool {
        window?.firstResponder == self
    }

    var windowIsKey: Bool {
        window?.isKeyWindow ?? false
    }

    override func becomeFirstResponder() -> Bool {
        setSelectionNeedsDisplay()
        updateInsertionPointTimer()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        setSelectionNeedsDisplay()
        updateInsertionPointTimer()
        return super.resignFirstResponder()
    }

    @objc func windowDidBecomeKey(_ notification: Notification) {
        setSelectionNeedsDisplay()
        updateInsertionPointTimer()
    }

    @objc func windowDidResignKey(_ notification: Notification) {
        setSelectionNeedsDisplay()
        updateInsertionPointTimer()
    }

    override func keyDown(with event: NSEvent) {
        NSCursor.setHiddenUntilMouseMoves(true)

        if inputContext?.handleEvent(event) ?? false {
            return
        }

        // Don't know if handleEvent ever returns false here. Just want to know about it.
        fatalError("keyDown: inputContext didn't handle this event: \(event)")
    }

    // MARK: - Mouse events
    override func mouseDown(with event: NSEvent) {
        if inputContext?.handleEvent(event) ?? false {
            return
        }

        discardMarkedText()

        let locationInView = convert(event.locationInWindow, from: nil)
        let point = convertToTextContainer(locationInView)
        layoutManager.selection = SelectionNavigator.selection(interactingAt: point, dataSource: layoutManager)
    }

    override func mouseDragged(with event: NSEvent) {
        if inputContext?.handleEvent(event) ?? false {
            return
        }

        let locationInView = convert(event.locationInWindow, from: nil)
        extendSelection(to: locationInView)

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
