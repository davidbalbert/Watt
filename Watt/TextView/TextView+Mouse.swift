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

        var lastRoundedLocation: CGPoint?
        autoscroller = Autoscroller(self, event: event) { [weak self] locationInView in
            guard let self else { return }
            let roundedLocation = locationInView.rounded()
            defer { lastRoundedLocation = roundedLocation }

            if lastRoundedLocation == roundedLocation {
                return
            }

            let clamped = locationInView.clamped(to: visibleRect)
            let point = convertToTextContainer(clamped)
            selection = SelectionNavigator(selection).selection(extendingTo: point, dataSource: layoutManager)
        }
        autoscroller?.start()
    }

    override func mouseDragged(with event: NSEvent) {
        if inputContext?.handleEvent(event) ?? false {
            return
        }
        autoscroller?.update(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        inputContext?.handleEvent(event)
        autoscroller?.stop()
        autoscroller = nil
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.iBeam.set()
    }
}
