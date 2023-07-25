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
    }

    func extendSelection(to point: CGPoint) {
        guard let location = layoutManager.location(interactingAt: point) else {
            return
        }

        layoutManager.selection.head = location
    }

    private var insertionPointOnInterval: TimeInterval {
        UserDefaults.standard.double(forKey: "NSTextInsertionPointBlinkPeriodOn") / 1000
    }

    private var insertionPointOffInterval: TimeInterval {
        UserDefaults.standard.double(forKey: "NSTextInsertionPointBlinkPeriodOff") / 1000
    }

    private var insertionPointBlinkInterval: TimeInterval {
        if insertionPointLayer.isHidden {
            return insertionPointOnInterval
        } else {
            return insertionPointOffInterval
        }
    }

    func updateInsertionPointTimer() {
//        insertionPointTimer?.invalidate()
//
//        insertionPointLayer.isHidden = false
//
//        if insertionPointOffInterval == 0 {
//            return
//        }
//
//        if !(layoutManager.selection?.isEmpty ?? true) {
//            return
//        }
//
//        scheduleInsertionPointTimer()
    }

    func scheduleInsertionPointTimer() {
        insertionPointTimer = Timer.scheduledTimer(withTimeInterval: insertionPointBlinkInterval, repeats: false) { [weak self] timer in

            guard let self = self else { return }
            self.insertionPointLayer.isHidden.toggle()
            scheduleInsertionPointTimer()
        }
    }
}
