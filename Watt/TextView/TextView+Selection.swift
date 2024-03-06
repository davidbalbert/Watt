//
//  TextView+Selection.swift
//  Watt
//
//  Created by David Albert on 5/19/23.
//

import Cocoa

extension TextView {
    func setTypingAttributes() {
        if buffer.isEmpty {
            typingAttributes = defaultAttributes
        } else if selection.lowerBound == buffer.endIndex {
            typingAttributes = buffer.runs[buffer.index(before: selection.lowerBound)].attributes
        } else {
            typingAttributes = buffer.runs[selection.lowerBound].attributes
        }
    }

    private var insertionPointOnInterval: TimeInterval {
        UserDefaults.standard.textInsertionPointBlinkPeriodOn / 1000
    }

    private var insertionPointOffInterval: TimeInterval {
        UserDefaults.standard.textInsertionPointBlinkPeriodOff / 1000
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

        if selection.isRange {
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

    func scrollSelectionToVisible() {
        let head = selection.head

        let affinity: Selection.Affinity
        if selection.isCaret {
            affinity = selection.affinity
        } else {
            // A bit confusing: an upstream selection has head < anchor. Downstream has
            // anchor > head.
            // 
            // The head of an upstream selection is guaranteed to be on the downstream edge
            // of a line fragment boundary. The head of a downstream selection may be on the
            // upstream edge of a line fragment boundary if it's at the end.
            affinity = selection.affinity == .upstream ? .downstream : .upstream
        }

        let target: Buffer.Index
        if affinity == .upstream && head > buffer.startIndex {
            target = buffer.index(before: head)
        } else {
            target = head
        }

        scrollIndexToVisible(target)
    }

    func centerSelectionHead() {
        let head = selection.head

        let affinity: Selection.Affinity
        if selection.isCaret {
            affinity = selection.affinity
        } else {
            // see comment in scrollSelectionToVisible
            affinity = selection.affinity == .upstream ? .downstream : .upstream
        }

        let target: Buffer.Index
        if affinity == .upstream && head > buffer.startIndex {
            target = buffer.index(before: head)
        } else {
            target = head
        }

        scrollIndexToCenter(target)
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
