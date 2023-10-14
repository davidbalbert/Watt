//
//  TextView+KeyBindings.swift
//  Watt
//
//  Created by David Albert on 5/24/23.
//

import Cocoa

// MARK: - NSStandardKeyBindingResponding

extension TextView {
    // List of all key commands for completeness testing: https://support.apple.com/en-us/HT201236
    // NSStandardKeyBindingResponding: https://developer.apple.com/documentation/appkit/nsstandardkeybindingresponding

    // MARK: Movement

    override func moveForward(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.isEmpty && selection.lowerBound == buffer.endIndex {
            updateInsertionPointTimer()
            return
        }

        let head: Buffer.Index
        let affinity: Selection.Affinity

        if selection.isEmpty {
            head = buffer.index(after: selection.lowerBound)
            affinity = head == buffer.endIndex ? .upstream : .downstream
        } else {
            // If the selection ends at the end of a visual line, we want
            // affinity to be upstream so that when we press the right
            // arrow key, the caret doesn't end up on the next visual line.
            let line = layoutManager.line(containing: selection.upperBound)!
            let frag = line.fragment(containing: selection.upperBound, affinity: .upstream)!

            head = selection.upperBound
            affinity = head == frag.range.upperBound ? .upstream : .downstream
        }

        let xOffset = layoutManager.position(forCharacterAt: head, affinity: affinity).x
        layoutManager.selection = Selection(head: head, affinity: affinity, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveRight(_ sender: Any?) {
        moveForward(sender)
    }

    override func moveBackward(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.isEmpty && selection.lowerBound == buffer.startIndex {
            updateInsertionPointTimer()
            return
        }

        let head: Buffer.Index

        if selection.isEmpty {
            head = buffer.index(before: selection.lowerBound)
        } else {
            head = selection.lowerBound
        }

        let xOffset = layoutManager.position(forCharacterAt: head, affinity: .downstream).x
        layoutManager.selection = Selection(head: head, affinity: .downstream, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveLeft(_ sender: Any?) {
        moveBackward(sender)
    }

    // Moving up and down when the selection is not empty:
    // - Xcode: always relative to the selection's lower bound
    // - Nova: same as Xcode
    // - TextEdit: always relative to the selection's anchor
    // - TextMate: always relative to the selection's head
    // - VS Code: lower bound when moving up, upper bound when moving down
    // - Zed: Same as VS Code
    // - Sublime Text: Same as VS Code
    //
    // I'm going to match Xcode and Nova for now, but I'm not sure which
    // option is most natural.
    //
    // To get the correct behavior, we need to ensure that selection.xOffset
    // always corresponds to selection.lowerBound.

    override func moveUp(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        guard let line = layoutManager.line(containing: selection.lowerBound) else {
            return
        }
        guard let frag = line.fragment(containing: selection.lowerBound, affinity: selection.affinity) else {
            return
        }

        if frag.range.lowerBound == buffer.startIndex {
            let xOffset = layoutManager.position(forCharacterAt: buffer.startIndex, affinity: .downstream).x
            layoutManager.selection = Selection(head: buffer.startIndex, affinity: .downstream, xOffset: xOffset)
        } else {
            let pointInLine = CGPoint(
                x: selection.xOffset,
                y: frag.alignmentFrame.minY - 0.0001
            )
            let point = layoutManager.convert(pointInLine, from: line)
            guard let (head, affinity) = layoutManager.locationAndAffinity(interactingAt: point) else {
                return
            }

            layoutManager.selection = Selection(head: head, affinity: affinity, xOffset: selection.xOffset)
        }

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveDown(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        guard let line = layoutManager.line(containing: selection.lowerBound) else {
            return
        }
        guard let frag = line.fragment(containing: selection.lowerBound, affinity: selection.affinity) else {
            return
        }

        if frag.range.upperBound == buffer.endIndex {
            let xOffset = layoutManager.position(forCharacterAt: buffer.endIndex, affinity: .upstream).x
            layoutManager.selection = Selection(head: buffer.endIndex, affinity: .upstream, xOffset: xOffset)
        } else {
            let pointInLine = CGPoint(
                x: selection.xOffset,
                y: frag.alignmentFrame.maxY
            )
            let point = layoutManager.convert(pointInLine, from: line)
            guard let (head, affinity) = layoutManager.locationAndAffinity(interactingAt: point) else {
                return
            }

            layoutManager.selection = Selection(head: head, affinity: affinity, xOffset: selection.xOffset)
        }

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveWordForward(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.isEmpty && selection.lowerBound == buffer.endIndex {
            updateInsertionPointTimer()
            return
        }

        var head = selection.upperBound
        while head < buffer.endIndex && isWordBoundary(buffer[head]) {
            head = buffer.index(after: head)
        }
        while head < buffer.endIndex && !isWordBoundary(buffer[head]) {
            head = buffer.index(after: head)
        }

        let affinity: Selection.Affinity = head == buffer.endIndex ? .upstream : .downstream

        let xOffset = layoutManager.position(forCharacterAt: head, affinity: affinity).x
        layoutManager.selection = Selection(head: head, affinity: affinity, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveWordBackward(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.isEmpty && selection.lowerBound == buffer.startIndex {
            updateInsertionPointTimer()
            return
        }

        var head = selection.lowerBound
        while head > buffer.startIndex && isWordBoundary(buffer[buffer.index(before: head)]) {
            head = buffer.index(before: head)
        }
        while head > buffer.startIndex && !isWordBoundary(buffer[buffer.index(before: head)]) {
            head = buffer.index(before: head)
        }

        let xOffset = layoutManager.position(forCharacterAt: head, affinity: .downstream).x
        layoutManager.selection = Selection(head: head, affinity: .downstream, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }



    override func moveWordRight(_ sender: Any?) {
        moveWordForward(sender)
    }

    override func moveWordLeft(_ sender: Any?) {
        moveWordBackward(sender)
    }

    // MARK: - Selection

    override func selectAll(_ sender: Any?) {
        discardMarkedText()

        layoutManager.selection = Selection(head: buffer.endIndex, anchor: buffer.startIndex, affinity: .downstream)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }

    // MARK: - Insertion and indentation

    override func insertTab(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        replaceSubrange(selection.range, with: AttributedRope("\t", attributes: typingAttributes))
        unmarkText()
    }


    override func insertNewline(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        replaceSubrange(selection.range, with: AttributedRope("\n", attributes: typingAttributes))
        unmarkText()
    }

    override func insertNewlineIgnoringFieldEditor(_ sender: Any?) {
        insertNewline(sender)
    }

    override func insertTabIgnoringFieldEditor(_ sender: Any?) {
        insertTab(sender)
    }

    // MARK: - Deletion

    override func deleteForward(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if !selection.isEmpty {
            replaceSubrange(selection.range, with: "")
        } else if selection.lowerBound < buffer.endIndex {
            let end = buffer.index(after: selection.lowerBound)
            replaceSubrange(selection.lowerBound..<end, with: "")
        }
        unmarkText()
    }

    override func deleteBackward(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if !selection.isEmpty {
            replaceSubrange(selection.range, with: "")
        } else if selection.lowerBound > buffer.startIndex {
            let start = buffer.index(before: selection.lowerBound)
            replaceSubrange(start..<selection.lowerBound, with: "")
        }
        unmarkText()
    }

    override func deleteWordForward(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if !selection.isEmpty {
            replaceSubrange(selection.range, with: "")
        } else if selection.lowerBound < buffer.endIndex {
            let caret = selection.lowerBound
            var end = caret

            while end < buffer.endIndex && isWordBoundary(buffer[end]) {
                end = buffer.index(after: end)
            }
            while end < buffer.endIndex && !isWordBoundary(buffer[end]) {
                end = buffer.index(after: end)
            }

            replaceSubrange(caret..<end, with: "")
        }
        unmarkText()
    }

    override func deleteWordBackward(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if !selection.isEmpty {
            replaceSubrange(selection.range, with: "")
        } else if selection.lowerBound > buffer.startIndex {
            let caret = selection.lowerBound
            var start = buffer.index(before: caret)

            while start > buffer.startIndex && isWordBoundary(buffer[buffer.index(before: start)]) {
                start = buffer.index(before: start)
            }

            while start > buffer.startIndex && !isWordBoundary(buffer[buffer.index(before: start)]) {
                start = buffer.index(before: start)
            }

            replaceSubrange(start..<caret, with: "")
        }
        unmarkText()
    }
}

fileprivate func isWordBoundary(_ c: Character) -> Bool {
    c.isWhitespace || c.isPunctuation
}
