//
//  TextView+Input.swift
//  Watt
//
//  Created by David Albert on 5/24/23.
//

import Cocoa

extension TextView: NSTextInputClient {
    func insertText(_ string: Any, replacementRange: NSRange) {
        guard let range = getReplacementRange(for: replacementRange) else {
            return
        }

        let attrRope: AttributedRope
        if let attrStr = string as? NSAttributedString {
            attrRope = AttributedRope(attrStr, merging: typingAttributes)
        } else {
            attrRope = AttributedRope(string as! String, attributes: typingAttributes)
        }

        buffer.replaceSubrange(range, with: attrRope)

        print("insertText - ", terminator: "")
        unmarkText()
    }

    override func doCommand(by selector: Selector) {
        print("doCommand(by: #selector(\(selector)))")
        if responds(to: selector) {
            perform(selector, with: nil)
        }
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        guard let range = getReplacementRange(for: replacementRange) else {
            return
        }

        let attrRope: AttributedRope
        if let attrStr = string as? NSAttributedString {
            attrRope = AttributedRope(attrStr, merging: typingAttributes)
        } else {
            attrRope = AttributedRope(string as! String, attributes: typingAttributes.merging(markedTextAttributes))
        }

        buffer.replaceSubrange(range, with: attrRope)

        let start = buffer.index(fromOldIndex: range.lowerBound)
        let anchor = buffer.utf16.index(start, offsetBy: selectedRange.lowerBound)
        let head = buffer.utf16.index(anchor, offsetBy: selectedRange.length)

        var selection = Selection(head: head, anchor: anchor)

        if attrRope.count == 0 {
            print("setMarkedText -  ", terminator: "")
            unmarkText()
        } else {
            print("setMarkedText")
            let end = buffer.index(start, offsetBy: attrRope.count)
            selection.markedRange = start..<end
        }

        layoutManager.selection = selection
    }

    func unmarkText() {
        print("unmarkText")
        layoutManager.selection?.markedRange = nil

        // TODO: if we're the only one who calls unmarkText(), we can remove
        // these layout calls, because we already do layout in didInvalidateLayout(for layoutManager: LayoutManager)
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
        guard let selection = layoutManager.selection else {
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

        let clamped = range.clamped(to: documentRange)
        actualRange?.pointee = NSRange(clamped, in: buffer)

        return buffer.attributedSubstring(for: clamped)
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        // Derived from NSTextView on macOS 13.4. I left out NSTextInsertionUndoable and
        // NSTextInputReplacementRangeAttributeName, which are private.
        return [.font, .underlineStyle, .foregroundColor, .backgroundColor, .underlineColor, .markedClauseSegment, .languageIdentifier, .glyphInfo, .textAlternatives, .attachment]

    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let range = Range(range, in: buffer) else {
            return .zero
        }

        var rect: CGRect = .zero
        layoutManager.enumerateTextSegments(in: range, type: .standard) { segmentRange, frame in
            rect = frame
            actualRange?.pointee = NSRange(segmentRange, in: buffer)

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

        return buffer.utf16.distance(from: buffer.startIndex, to: characterIndex)
    }
}

extension TextView {
    private func getReplacementRange(for proposed: NSRange) -> Range<Buffer.Index>? {
        if proposed != .notFound {
            return Range(proposed, in: buffer)
        }

        return layoutManager.selection?.markedRange ?? layoutManager.selection?.range
    }
}
