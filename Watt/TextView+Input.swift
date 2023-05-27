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
        // TODO
    }

    func unmarkText() {
        // TODO
    }

    func selectedRange() -> NSRange {
        if let range = layoutManager.selection?.range {
            return contentManager.nsRange(from: range)
        } else {
            return .notFound
        }
    }

    func markedRange() -> NSRange {
        .notFound
    }

    func hasMarkedText() -> Bool {
        false
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
        .zero
    }

    func characterIndex(for screenPoint: NSPoint) -> Int {
        NSNotFound
    }
}

extension TextView {
    private func attributedString(anyString: Any) -> NSAttributedString {
        if let string = anyString as? String {
            return NSAttributedString(string: string, attributes: [.font: font])
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

        return contentManager.nsRange(from: selection.range)
    }
}
