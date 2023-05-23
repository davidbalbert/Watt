//
//  TextView+Selection.swift
//  Watt
//
//  Created by David Albert on 5/19/23.
//

import Cocoa

extension TextView {
    func startSelection(at point: CGPoint) {
        guard let (location, affinity) = layoutManager.locationAndAffinity(interactingAt: point) else {
            return
        }

        layoutManager.selection = Selection(head: location, affinity: affinity)
        selectionLayer.needsLayout()
    }

    func extendSelection(to point: CGPoint) {
        guard let location = layoutManager.location(interactingAt: point) else {
            return
        }

        layoutManager.selection?.head = location
        selectionLayer.needsLayout()
    }

    // TODO: split into an onInterval and offInterval and read NSTextInsertionPointBlinkPeriodOn and NSTextInsertionPointBlinkPeriodOff from defaults
    private var insertionPointBlinkInterval: TimeInterval {
        0.5
    }

    func updateInsertionPointTimer() {
        insertionPointTimer?.invalidate()

        insertionPointLayer.isHidden = false

        insertionPointTimer = Timer.scheduledTimer(withTimeInterval: insertionPointBlinkInterval, repeats: true) { [weak self] timer in

            guard let self = self else { return }
            self.insertionPointLayer.isHidden.toggle()
        }
    }
}
