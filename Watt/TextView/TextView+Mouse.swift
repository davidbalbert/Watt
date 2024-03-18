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
            selection = SelectionNavigator(selection).selection(extendingTo: point, dataSource: layoutManager)
        } else if event.clickCount == 1 {
            selection = SelectionNavigator.selection(interactingAt: point, dataSource: layoutManager)
        } else if event.clickCount == 2 {
            selection = SelectionNavigator(selection).selection(for: .word, enclosing: point, dataSource: layoutManager)
        } else if event.clickCount == 3 {
            selection = SelectionNavigator(selection).selection(for: .paragraph, enclosing: point, dataSource: layoutManager)
        }

        var mouseEvent = event
        var done = false
        NSEvent.startPeriodicEvents(afterDelay: 0.1, withPeriod: 0.05)

        while !done {
            guard let nextEvent = NSApp.nextEvent(matching: [.leftMouseUp, .leftMouseDragged, .periodic], until: .distantFuture, inMode: .eventTracking, dequeue: true) else {
                print("Unexpected nil event, should not expire")
                continue
            }

            switch nextEvent.type {
            case .periodic:
                autoscroll(with: mouseEvent)
                extendSelection(with: mouseEvent)
                // Don't dispatch periodic events to NSApp. Doesn't really matter in practice, but
                // NSApp doesn't normally receive periodic events, so let's not rock the boat.
                continue
            case .leftMouseUp:
                done = true
            case .leftMouseDragged:
                mouseEvent = nextEvent
            default:
                print("Unexpected event type \(nextEvent.type)")
            }

            NSApp.sendEvent(nextEvent)
        }

        NSEvent.stopPeriodicEvents()
    }

    override func mouseDragged(with event: NSEvent) {
        if inputContext?.handleEvent(event) ?? false {
            return
        }

        extendSelection(with: event)
    }

    func extendSelection(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)
        let clamped = locationInView.clamped(to: visibleRect)
        let point = convertToTextContainer(clamped)
        selection = SelectionNavigator(selection).selection(extendingTo: point, dataSource: layoutManager)
    }

    override func mouseUp(with event: NSEvent) {
        inputContext?.handleEvent(event)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.iBeam.set()
    }
}
