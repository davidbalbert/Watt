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
            layoutManager.selection = SelectionNavigator(selection).selection(extendingTo: point, dataSource: layoutManager)
            return
        }

        switch event.clickCount {
        case 1:
            layoutManager.selection = SelectionNavigator.selection(interactingAt: point, dataSource: layoutManager)
        case 2:
            layoutManager.selection = SelectionNavigator(selection).selection(for: .word, enclosing: point, dataSource: layoutManager)
        case 3:
            layoutManager.selection = SelectionNavigator(selection).selection(for: .paragraph, enclosing: point, dataSource: layoutManager)
        default:
            break
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
                continue // don't sendEvent
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
        layoutManager.selection = SelectionNavigator(selection).selection(extendingTo: point, dataSource: layoutManager)
    }

    override func mouseUp(with event: NSEvent) {
        inputContext?.handleEvent(event)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.iBeam.set()
    }
}
