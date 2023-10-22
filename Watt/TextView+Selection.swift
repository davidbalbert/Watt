//
//  TextView+Selection.swift
//  Watt
//
//  Created by David Albert on 5/19/23.
//

import Cocoa

extension TextView {
    func startSelection(at locationInView: CGPoint) {
        let point = convertToTextContainer(locationInView)
        let (location, affinity) = layoutManager.locationAndAffinity(interactingAt: point)
        layoutManager.selection = Selection(caretAt: location, affinity: affinity)
    }

    func extendSelection(to locationInView: CGPoint) {
        let point = convertToTextContainer(locationInView)
        let location = layoutManager.location(interactingAt: point)
        layoutManager.selection = Selection(anchor: selection.anchor, head: location)
    }

    func setTypingAttributes() {
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

    func setTextNeedsDisplay() {
        for l in textLayer.sublayers ?? [] {
            l.setNeedsDisplay()
        }
    }

    func setSelectionNeedsDisplay() {
        for l in selectionLayer.sublayers ?? [] {
            l.setNeedsDisplay()
        }
    }

    func setInsertionPointNeedsDisplay() {
        for l in insertionPointLayer.sublayers ?? [] {
            l.setNeedsDisplay()
        }
    }

    var shouldDrawInsertionPoint: Bool {
        isFirstResponder && windowIsKey && superview != nil
    }

    func updateInsertionPointTimer() {
        insertionPointTimer?.invalidate()

        guard shouldDrawInsertionPoint else {
            insertionPointLayer.isHidden = true
            return
        }

        insertionPointLayer.isHidden = false

        if insertionPointOffInterval == 0 {
            return
        }

        if !selection.isCaret {
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
    func effectiveAppearance(for selectionLayer: SelectionLayer) -> NSAppearance {
        effectiveAppearance
    }
    
    func selectedTextBackgroundColor(for selectionLayer: SelectionLayer) -> NSColor {
        if windowIsKey && isFirstResponder {
            return theme.selectedTextBackgroundColor
        } else {
            return .unemphasizedSelectedTextBackgroundColor
        }
    }
}

extension TextView: InsertionPointLayerDelegate {
    func effectiveAppearance(for insertionPointLayer: InsertionPointLayer) -> NSAppearance {
        effectiveAppearance
    }
    
    func insertionPointColor(for selectionLayer: InsertionPointLayer) -> NSColor {
        theme.insertionPointColor
    }
}
