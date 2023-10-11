//
//  TextView+Actions.swift
//  Watt
//
//  Created by David Albert on 5/24/23.
//

import Cocoa

// MARK: - NSStandardKeyBindingResponding

extension TextView {
    // MARK: - Text insertion

    // List of all key commands for completeness testing: https://support.apple.com/en-us/HT201236
    // NSStandardKeyBindingResponding: https://developer.apple.com/documentation/appkit/nsstandardkeybindingresponding

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

    override func insertTab(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        replaceSubrange(selection.range, with: AttributedRope("\t", attributes: typingAttributes))
        unmarkText()
    }

    override func insertTabIgnoringFieldEditor(_ sender: Any?) {
        insertTab(sender)
    }

    // MARK: - Text deletion

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

    // MARK: Character navigation

    override func moveLeft(_ sender: Any?) {
        moveBackward(sender)
    }

    override func moveBackward(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if !selection.isEmpty || selection.lowerBound == buffer.startIndex {
            layoutManager.selection = Selection(head: selection.lowerBound)
        } else if selection.lowerBound > buffer.startIndex {
            layoutManager.selection = Selection(head: buffer.index(before: selection.lowerBound))
        }
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveRight(_ sender: Any?) {
        moveForward(sender)
    }

    override func moveForward(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if !selection.isEmpty || selection.upperBound == buffer.endIndex {
            layoutManager.selection = Selection(head: selection.upperBound)
        } else if selection.lowerBound < buffer.endIndex {
            layoutManager.selection = Selection(head: buffer.index(after: selection.lowerBound))
        }
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    // MARK: - Selection

    override func selectAll(_ sender: Any?) {
        discardMarkedText()

        layoutManager.selection = Selection(head: buffer.endIndex, anchor: buffer.startIndex, affinity: .downstream)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }
}

fileprivate func isWordBoundary(_ c: Character) -> Bool {
    c.isWhitespace || c.isPunctuation
}
