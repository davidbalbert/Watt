//
//  TextView+Input.swift
//  Watt
//
//  Created by David Albert on 5/24/23.
//

import Cocoa

extension TextView: NSTextInputClient {
    func insertText(_ string: Any, replacementRange: NSRange) {
        let string = attributedString(anyString: string)

        guard let range = getReplacementRange(for: replacementRange) else {
            return
        }

        contentManager.performEditingTransaction {
            contentManager.replaceCharacters(in: range, with: string)
        }

        updateInsertionPointTimer()
        unmarkText()
        inputContext?.invalidateCharacterCoordinates()

        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        let string = attributedString(anyString: string, attributes: markedTextAttributes)

        guard let range = getReplacementRange(for: replacementRange) else {
            return
        }

        contentManager.performEditingTransaction {
            contentManager.replaceCharacters(in: range, with: string)
        }

        let anchor = contentManager.location(contentManager.documentRange.lowerBound, offsetBy: range.location + selectedRange.location)
        let head = contentManager.location(anchor, offsetBy: selectedRange.length)
        layoutManager.selection = Selection(head: head, anchor: anchor)

        if string.length == 0 {
            unmarkText()
        } else {
            let start = contentManager.location(contentManager.documentRange.lowerBound, offsetBy: range.location)
            let end = contentManager.location(start, offsetBy: string.length)
            layoutManager.selection?.markedRange = start..<end
        }

        updateInsertionPointTimer()
        inputContext?.invalidateCharacterCoordinates()

        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }

    func unmarkText() {
        layoutManager.selection?.markedRange = nil

        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }

    func selectedRange() -> NSRange {
        if let range = layoutManager.selection?.range {
            return contentManager.nsRange(from: range)
        } else {
            return .notFound
        }
    }

    func markedRange() -> NSRange {
        guard let markedRange = layoutManager.selection?.markedRange else {
            return .notFound
        }

        return contentManager.nsRange(from: markedRange)
    }

    func hasMarkedText() -> Bool {
        layoutManager.selection?.markedRange != nil
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        if let range = range.intersection(contentManager.documentNSRange) {
            return contentManager.attributedSubstring(for: range)
        } else {
            return nil
        }
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        // Derived from NSTextView on macOS 13.4. I left out NSTextInsertionUndoable and
        // NSTextInputReplacementRangeAttributeName, which are private.
        return [.font, .underlineStyle, .foregroundColor, .backgroundColor, .underlineColor, .markedClauseSegment, .languageIdentifier, .glyphInfo, .textAlternatives, .attachment]

    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let range = contentManager.range(from: range) else {
            return .zero
        }

        var rect: CGRect = .zero
        layoutManager.enumerateTextSegments(in: range, type: .standard) { segmentRange, frame in
            rect = frame

            if let actualRange {
                actualRange.pointee = contentManager.nsRange(from: segmentRange)
            }

            return false
        }

        let viewRect = convertFromTextContainer(rect)
        let windowRect = convert(viewRect, to: nil)
        let screenRect = window?.convertToScreen(windowRect) ?? .zero

        return screenRect
    }

    func characterIndex(for screenPoint: NSPoint) -> Int {
        guard let window else {
            return NSNotFound
        }

        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let viewPoint = convert(windowPoint, from: nil)
        let textContainerPoint = convertToTextContainer(viewPoint)

        guard let characterIndex = layoutManager.location(interactingAt: textContainerPoint) else {
            return NSNotFound
        }

        return contentManager.offset(from: contentManager.documentRange.lowerBound, to: characterIndex)
    }

    override func doCommand(by selector: Selector) {
        print("doCommand(by: #selector(\(selector)))")
        if responds(to: selector) {
            perform(selector, with: nil)
        }
    }
}

extension TextView {
    var typingAttributes: [NSAttributedString.Key: Any] {
        [.font: font]
    }

    private func attributedString(anyString: Any, attributes: [NSAttributedString.Key: Any] = [:]) -> NSAttributedString {
        if let string = anyString as? String {
            let merged = attributes.merging(typingAttributes) { k1, _ in k1 }
            return NSAttributedString(string: string, attributes: merged)
        } else {
            return anyString as! NSAttributedString
        }
    }

    private func getReplacementRange(for proposed: NSRange) -> NSRange? {
        if proposed != .notFound {
            return proposed
        }

        guard let selection = layoutManager.selection else {
            return nil
        }

        let range = selection.markedRange ?? selection.range

        return contentManager.nsRange(from: range)
    }

    var markedTextAttributes: [NSAttributedString.Key : Any] {
        [
            .backgroundColor: NSColor.systemYellow.withSystemEffect(.disabled),
        ]
    }
}
