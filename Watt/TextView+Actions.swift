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

        print("insertNewline - ", terminator: "")
        unmarkText()
    }

    override func insertNewlineIgnoringFieldEditor(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        replaceSubrange(selection.range, with: AttributedRope("\n", attributes: typingAttributes))

        print("insertNewlineIgnoringFieldEditor - ", terminator: "")
        unmarkText()
    }

    override func insertTab(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        replaceSubrange(selection.range, with: AttributedRope("\t", attributes: typingAttributes))

        print("insertTab - ", terminator: "")
        unmarkText()
    }

    override func insertTabIgnoringFieldEditor(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        replaceSubrange(selection.range, with: AttributedRope("\t", attributes: typingAttributes))

        print("insertTabIgnoringFieldEditor - ", terminator: "")
        unmarkText()
    }

    // MARK: - Text deletion

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
