//
//  TextView+Actions.swift
//  Watt
//
//  Created by David Albert on 5/24/23.
//

import Cocoa

extension TextView {
    // MARK: - Text input

    // List of all key commands for completeness testing: https://support.apple.com/en-us/HT201236
    // NSStandardKeyBindingResponding: https://developer.apple.com/documentation/appkit/nsstandardkeybindingresponding

    override func insertNewline(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        // TODO: we probably have to take selection.markedRange into account here.
        buffer.replaceSubrange(selection.range, with: AttributedRope("\n", attributes: typingAttributes))

        print("insertNewline - ", terminator: "")
        unmarkText()
    }

    // MARK: - Selection

    override func selectAll(_ sender: Any?) {
        discardMarkedText()

        layoutManager.selection = Selection(head: buffer.endIndex, anchor: buffer.startIndex, affinity: .downstream)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }
}
