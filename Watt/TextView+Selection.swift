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
        setTypingAttributes()
    }

    func extendSelection(to point: CGPoint) {
        guard let location = layoutManager.location(interactingAt: point) else {
            return
        }

        layoutManager.selection?.head = location
        setTypingAttributes()
    }

    func setTypingAttributes() {
        guard let selection = layoutManager.selection else {
            return
        }

        if buffer.isEmpty {
            typingAttributes = defaultAttributes
        } else if selection.lowerBound == buffer.endIndex {
            typingAttributes = buffer.getAttributes(at: buffer.index(before: selection.lowerBound))
        } else {
            typingAttributes = buffer.getAttributes(at: selection.lowerBound)
        }
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

    func setSelectionNeedsDisplay() {
        for l in selectionLayer.sublayers ?? [] {
            l.setNeedsDisplay()
        }
    }

    var shouldDrawInsertionPoint: Bool {
        isFirstResponder && windowIsKey && superview != nil
    }

    func updateInsertionPointTimer() {
        insertionPointTimer?.invalidate()

        guard let selection = layoutManager.selection else {
            return
        }

        guard shouldDrawInsertionPoint else {
            insertionPointLayer.isHidden = true
            return
        }

        insertionPointLayer.isHidden = false

        if insertionPointOffInterval == 0 {
            return
        }

        if !selection.isEmpty {
            return
        }

        scheduleInsertionPointTimer()
    }

    func scheduleInsertionPointTimer() {
        insertionPointTimer = Timer.scheduledTimer(withTimeInterval: insertionPointBlinkInterval, repeats: false) { [weak self] timer in
            guard let self = self else { return }
            self.insertionPointLayer.isHidden.toggle()
            scheduleInsertionPointTimer()
        }
    }
}

extension TextView: SelectionLayerDelegate {
    func textSelectionBackgroundColor(for selectionLayer: SelectionLayer) -> NSColor {
        if windowIsKey && isFirstResponder {
            return .selectedTextBackgroundColor
        } else {
            return .unemphasizedSelectedTextBackgroundColor
        }
    }
}
