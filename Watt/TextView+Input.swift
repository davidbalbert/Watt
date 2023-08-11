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

        buffer.replaceSubrange(range, with: string)

        updateInsertionPointTimer()
        unmarkText()
        inputContext?.invalidateCharacterCoordinates()

        textLayer.setNeedsLayout()
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }

    // TODO: when re-enabling marked text, make sure to look at insertNewline(_:) and see if there's anything we have to change.
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        let string = attributedString(anyString: string, attributes: markedTextAttributes)

        guard let range = getReplacementRange(for: replacementRange) else {
            return
        }

//        buffer.performEditingTransaction {
//            buffer.replaceCharacters(in: range, with: string)
//        }
//
//        let anchor = buffer.index(buffer.documentRange.lowerBound, offsetBy: range.location + selectedRange.location)
//        let head = buffer.index(anchor, offsetBy: selectedRange.length)
//        layoutManager.selection = Selection(head: head, anchor: anchor)
//
//        if string.length == 0 {
//            unmarkText()
//        } else {
//            let start = buffer.index(buffer.documentRange.lowerBound, offsetBy: range.location)
//            let end = buffer.index(start, offsetBy: string.length)
//            layoutManager.selection.markedRange = start..<end
//        }

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
        guard let range = layoutManager.selection?.range else {
            return .notFound
        }

        return NSRange(range, in: buffer)
    }

    func markedRange() -> NSRange {
        guard let markedRange = layoutManager.selection?.markedRange else {
            return .notFound
        }

        return NSRange(markedRange, in: buffer)
    }

    func hasMarkedText() -> Bool {
        guard let selection else {
            return false
        }

        return selection.markedRange != nil
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        guard let range = Range(range, in: buffer) else {
            return nil
        }

        let documentRange = buffer.documentRange

        if !range.overlaps(documentRange) {
            return nil
        }

        return buffer.attributedSubstring(for: range.clamped(to: documentRange))
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        // Derived from NSTextView on macOS 13.4. I left out NSTextInsertionUndoable and
        // NSTextInputReplacementRangeAttributeName, which are private.
        return [.font, .underlineStyle, .foregroundColor, .backgroundColor, .underlineColor, .markedClauseSegment, .languageIdentifier, .glyphInfo, .textAlternatives, .attachment]

    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
//        guard let range = buffer.range(from: range) else {
//            return .zero
//        }
//
//        var rect: CGRect = .zero
//        layoutManager.enumerateTextSegments(in: range, type: .standard) { segmentRange, frame in
//            rect = frame
//
//            if let actualRange {
//                actualRange.pointee = buffer.nsRange(from: segmentRange)
//            }
//
//            return false
//        }
//
//        let viewRect = convertFromTextContainer(rect)
//        let windowRect = convert(viewRect, to: nil)
//        let screenRect = window?.convertToScreen(windowRect) ?? .zero
//
//        return screenRect
        .zero
    }

    func characterIndex(for screenPoint: NSPoint) -> Int {
//        guard let window else {
//            return NSNotFound
//        }
//
//        let windowPoint = window.convertPoint(fromScreen: screenPoint)
//        let viewPoint = convert(windowPoint, from: nil)
//        let textContainerPoint = convertToTextContainer(viewPoint)
//
//        guard let characterIndex = layoutManager.location(interactingAt: textContainerPoint) else {
//            return NSNotFound
//        }
//
//        return buffer.offset(from: buffer.documentRange.lowerBound, to: characterIndex)
        .zero
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

    private func getReplacementRange(for proposed: NSRange) -> Range<Buffer.Index>? {
        if proposed != .notFound {
            return Range(proposed, in: buffer)
        }

        return layoutManager.selection?.markedRange ?? layoutManager.selection?.range
    }

    var markedTextAttributes: [NSAttributedString.Key : Any] {
        [
            .backgroundColor: NSColor.systemYellow.withSystemEffect(.disabled),
        ]
    }
}
