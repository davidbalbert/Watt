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
        guard let selection else {
            return
        }

        // TODO: we probably have to take selection.markedRange into account here.
        // TODO: get rid of NSAttributedString creation
        buffer.replaceSubrange(selection.range, with: NSAttributedString(string: "\n", attributes: typingAttributes))
        
        updateInsertionPointTimer()
        unmarkText()
        inputContext?.invalidateCharacterCoordinates()
    }

    // MARK: - Selection

    override func selectAll(_ sender: Any?) {
        layoutManager.selection = Selection(head: buffer.documentRange.upperBound, anchor: buffer.documentRange.lowerBound, affinity: .downstream)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
    }
}
