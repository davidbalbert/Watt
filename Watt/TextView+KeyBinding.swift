//
//  TextView+KeyBinding.swift
//  Watt
//
//  Created by David Albert on 5/24/23.
//

import Cocoa
import StandardKeyBindingResponder

// MARK: - NSStandardKeyBindingResponding

extension TextView {
    // List of all key commands for completeness testing: https://support.apple.com/en-us/HT201236
    // NSStandardKeyBindingResponding: https://developer.apple.com/documentation/appkit/nsstandardkeybindingresponding

    // MARK: Movement

    override func moveForward(_ sender: Any?) {
        layoutManager.moveSelection(.right)
    }

    override func moveRight(_ sender: Any?) {
        layoutManager.moveSelection(.right)
    }

    override func moveBackward(_ sender: Any?) {
        layoutManager.moveSelection(.left)
    }

    override func moveLeft(_ sender: Any?) {
        layoutManager.moveSelection(.left)
    }

    override func moveUp(_ sender: Any?) {
        layoutManager.moveSelection(.up)
    }

    override func moveDown(_ sender: Any?) {
        layoutManager.moveSelection(.down)
    }

    override func moveWordForward(_ sender: Any?) {
        layoutManager.moveSelection(.rightWord)
    }

    override func moveWordBackward(_ sender: Any?) {
        layoutManager.moveSelection(.leftWord)
    }

    override func moveToBeginningOfLine(_ sender: Any?) {
        layoutManager.moveSelection(.beginningOfLine)
    }

    override func moveToEndOfLine(_ sender: Any?) {
        layoutManager.moveSelection(.endOfLine)
    }

    override func moveToBeginningOfParagraph(_ sender: Any?) {
        layoutManager.moveSelection(.beginningOfParagraph)
    }

    override func moveToEndOfParagraph(_ sender: Any?) {
        layoutManager.moveSelection(.endOfParagraph)
    }

    override func moveToEndOfDocument(_ sender: Any?) {
        layoutManager.moveSelection(.endOfDocument)
    }

    override func moveToBeginningOfDocument(_ sender: Any?) {
        layoutManager.moveSelection(.beginningOfDocument)
    }

    override func pageDown(_ sender: Any?) {
        // TODO: I don't think any of these calls to convertToTextContainer are correct.
        // We're using viewport.height down below, but the if there's a top or bottom
        // inset on the text container, the container will be shorter than the viewport.
        // I'm not sure the right way to handle this yet.
//        let viewport = convertToTextContainer(visibleRect)
//        let point = layoutManager.position(forCharacterAt: selection.upperBound, affinity: selection.isEmpty ? Affinity : .upstream)
//
//        let target = CGPoint(
//            x: selection.xOffset,
//            y: point.y + viewport.height
//        )
//
//        let (head, affinity) = layoutManager.locationAndAffinity(interactingAt: target)
//
//        layoutManager.selection = Selection(head: head, affinity: affinity, xOffset: selection.xOffset)
//
//        scroll(CGPoint(x: 0, y: target.y - viewport.height/2))
//
//        selectionLayer.setNeedsLayout()
//        insertionPointLayer.setNeedsLayout()
//        updateInsertionPointTimer()
    }

    override func pageUp(_ sender: Any?) {
//        let viewport = convertToTextContainer(visibleRect)
//        let point = layoutManager.position(forCharacterAt: selection.lowerBound, affinity: selection.isEmpty ? Affinity : .upstream)
//
//        let target = CGPoint(
//            x: selection.xOffset,
//            y: point.y - viewport.height
//        )
//
//        let (head, affinity) = layoutManager.locationAndAffinity(interactingAt: target)
//
//        layoutManager.selection = Selection(head: head, affinity: affinity, xOffset: selection.xOffset)
//
//        scroll(CGPoint(x: 0, y: target.y - viewport.height/2))
//
//        selectionLayer.setNeedsLayout()
//        insertionPointLayer.setNeedsLayout()
//        updateInsertionPointTimer()
    }

    override func centerSelectionInVisibleArea(_ sender: Any?) {
//        let viewport = convertToTextContainer(visibleRect)
//        let point = layoutManager.point(forCharacterAt: selection.lowerBound, affinity: .downstream)
//
//        scroll(CGPoint(x: 0, y: point.y - viewport.height/2))
//
//        selectionLayer.setNeedsLayout()
//        insertionPointLayer.setNeedsLayout()
//        updateInsertionPointTimer()
    }



    override func moveBackwardAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.left)
    }

    override func moveForwardAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.right)
    }

    override func moveWordForwardAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.rightWord)
    }

    override func moveWordBackwardAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.leftWord)
    }

    override func moveUpAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.up)
    }

    override func moveDownAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.down)
    }

    override func moveToBeginningOfLineAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.beginningOfLine)
    }

    override func moveToEndOfLineAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.endOfLine)
    }

    override func moveToBeginningOfParagraphAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.beginningOfParagraph)
    }

    override func moveToEndOfParagraphAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.endOfParagraph)
    }

    override func moveToEndOfDocumentAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.endOfDocument)
    }

    override func moveToBeginningOfDocumentAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.beginningOfDocument)
    }

    override func pageDownAndModifySelection(_ sender: Any?) {
//        let viewport = convertToTextContainer(visibleRect)
//        let point = layoutManager.position(forCharacterAt: selection.upperBound, affinity: selection.isEmpty ? Affinity : .upstream)
//
//        let target = CGPoint(
//            x: selection.xOffset,
//            y: point.y + viewport.height
//        )
//
//        let (head, affinity) = layoutManager.locationAndAffinity(interactingAt: target)
//
//        layoutManager.selection = Selection(head: head, anchor: selection.lowerBound, affinity: affinity, xOffset: selection.xOffset)
//
//        scroll(CGPoint(x: 0, y: target.y - viewport.height/2))
//
//        selectionLayer.setNeedsLayout()
//        insertionPointLayer.setNeedsLayout()
//        updateInsertionPointTimer()
    }

    override func pageUpAndModifySelection(_ sender: Any?) {
//        let viewport = convertToTextContainer(visibleRect)
//        let point = layoutManager.position(forCharacterAt: selection.lowerBound, affinity: selection.isEmpty ? Affinity : .upstream)
//
//        let target = CGPoint(
//            x: selection.xOffset,
//            y: point.y - viewport.height
//        )
//
//        let (head, affinity) = layoutManager.locationAndAffinity(interactingAt: target)
//
//        layoutManager.selection = Selection(head: head, anchor: selection.upperBound, affinity: affinity, xOffset: selection.xOffset)
//
//        scroll(CGPoint(x: 0, y: target.y - viewport.height/2))
//
//        selectionLayer.setNeedsLayout()
//        insertionPointLayer.setNeedsLayout()
//        updateInsertionPointTimer()
    }

    override func moveParagraphForwardAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.endOfParagraph)
    }

    override func moveParagraphBackwardAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.beginningOfParagraph)
    }



    override func moveWordRight(_ sender: Any?) {
        layoutManager.moveSelection(.rightWord)
    }

    override func moveWordLeft(_ sender: Any?) {
        layoutManager.moveSelection(.leftWord)
    }

    override func moveRightAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.right)
    }

    override func moveLeftAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.left)
    }

    override func moveWordRightAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.rightWord)
    }

    override func moveWordLeftAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.leftWord)
    }



    override func moveToLeftEndOfLine(_ sender: Any?) {
        layoutManager.moveSelection(.beginningOfLine)
    }

    override func moveToRightEndOfLine(_ sender: Any?) {
        layoutManager.moveSelection(.endOfLine)
    }

    override func moveToLeftEndOfLineAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.beginningOfLine)
    }

    override func moveToRightEndOfLineAndModifySelection(_ sender: Any?) {
        layoutManager.extendSelection(.endOfLine)
    }


    override func scrollPageUp(_ sender: Any?) {
        let viewport = convertToTextContainer(visibleRect)
        let point = CGPoint(
            x: 0,
            y: viewport.minY - viewport.height
        )

        animator().scroll(point)
    }

    override func scrollPageDown(_ sender: Any?) {
        let viewport = convertToTextContainer(visibleRect)
        let point = CGPoint(
            x: 0,
            y: viewport.maxY
        )

        animator().scroll(point)
    }

    override func scrollLineUp(_ sender: Any?) {
        let viewport = convertToTextContainer(visibleRect)
        let line = layoutManager.line(forVerticalOffset: viewport.minY - 0.0001)
        guard let frag = line.fragment(forVerticalOffset: viewport.minY - 0.0001) else {
            return
        }

        let frame = layoutManager.convert(frag.alignmentFrame, from: line)

        let target = CGPoint(
            x: 0,
            y: frame.minY
        )

        // not sure why this isn't animating? Maybe it doesn't animate for short changes?
        animator().scroll(convertFromTextContainer(target))
    }

    override func scrollLineDown(_ sender: Any?) {
        let viewport = convertToTextContainer(visibleRect)
        let line = layoutManager.line(forVerticalOffset: viewport.maxY)
        guard let frag = line.fragment(forVerticalOffset: viewport.maxY) else {
            return
        }

        let frame = layoutManager.convert(frag.alignmentFrame, from: line)

        let target = CGPoint(
            x: 0,
            y: frame.maxY - viewport.height
        )

        // not sure why this isn't animating? Maybe it doesn't animate for short changes?
        animator().scroll(convertFromTextContainer(target))
    }


    override func scrollToBeginningOfDocument(_ sender: Any?) {
        // TODO: this is broken. I think it's interacting with scroll adjustment...
        let point = CGPoint(
            x: 0,
            y: 0
        )

        animator().scroll(point)
    }

    override func scrollToEndOfDocument(_ sender: Any?) {
        let viewport = convertToTextContainer(visibleRect)
        let point = CGPoint(
            x: 0,
            y: layoutManager.contentHeight - viewport.height
        )

        animator().scroll(point)
    }

    // MARK: - Graphical element transposition

    override func transpose(_ sender: Any?) {
        guard let (i, j) = Transposer.indicesForTranspose(inSelectedRange: selection.range, dataSource: buffer) else {
            return
        }

        replaceSubrange((i...j).relative(to: buffer.text), with: String(buffer[j]) + String(buffer[i]))

        let anchor = buffer.index(fromOldIndex: i)
        let head = buffer.index(anchor, offsetBy: 2)
        layoutManager.selection = Selection(anchor: anchor, head: head, granularity: .character)
    }

    override func transposeWords(_ sender: Any?) {
        guard let (word1, word2) = Transposer.rangesForTransposeWords(inSelectedRange: selection.range, dataSource: buffer) else {
            return
        }

        var b = AttributedRope.Builder()
        b.push(buffer[word2])
        b.push(buffer[word1.upperBound..<word2.lowerBound])
        b.push(buffer[word1])

        replaceSubrange(word1.lowerBound..<word2.upperBound, with: b.build())

        let anchor = buffer.index(fromOldIndex: word1.lowerBound)
        let head = buffer.index(fromOldIndex: word2.upperBound)

        layoutManager.selection = Selection(anchor: anchor, head: head, granularity: .character)
    }

    // MARK: - Selection

    override func selectAll(_ sender: Any?) {
        discardMarkedText()

        if buffer.isEmpty {
            updateInsertionPointTimer()
            return
        }

        layoutManager.selection = Selection(anchor: buffer.startIndex, head: buffer.endIndex, granularity: .character)
    }

    // MARK: - Insertion and indentation

    override func insertTab(_ sender: Any?) {
        replaceSubrange(selection.range, with: AttributedRope("\t", attributes: typingAttributes))
        unmarkText()
    }


    override func insertNewline(_ sender: Any?) {
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
        if selection.isRange {
            replaceSubrange(selection.range, with: "")
        } else if selection.lowerBound < buffer.endIndex {
            let end = buffer.index(after: selection.lowerBound)
            replaceSubrange(selection.lowerBound..<end, with: "")
        }
        unmarkText()
    }

    override func deleteBackward(_ sender: Any?) {
        if selection.isRange {
            replaceSubrange(selection.range, with: "")
        } else if selection.lowerBound > buffer.startIndex {
            let start = buffer.index(before: selection.lowerBound)
            replaceSubrange(start..<selection.lowerBound, with: "")
        }
        unmarkText()
    }

    override func deleteWordForward(_ sender: Any?) {
        if selection.isRange {
            replaceSubrange(selection.range, with: "")
        } else if selection.lowerBound < buffer.endIndex {
            let caret = selection.lowerBound
            var end = caret

            while end < buffer.endIndex && !isWordChar(buffer[end]) {
                end = buffer.index(after: end)
            }
            while end < buffer.endIndex && isWordChar(buffer[end]) {
                end = buffer.index(after: end)
            }

            replaceSubrange(caret..<end, with: "")
        }
        unmarkText()
    }

    override func deleteWordBackward(_ sender: Any?) {
        if selection.isRange {
            replaceSubrange(selection.range, with: "")
        } else if selection.lowerBound > buffer.startIndex {
            let caret = selection.lowerBound
            var start = buffer.index(before: caret)

            // TODO: isWordChar should be defined elsewhere I think. Maybe StandardKeyBindingResponder?
            while start > buffer.startIndex && !isWordChar(buffer[buffer.index(before: start)]) {
                start = buffer.index(before: start)
            }

            while start > buffer.startIndex && isWordChar(buffer[buffer.index(before: start)]) {
                start = buffer.index(before: start)
            }

            replaceSubrange(start..<caret, with: "")
        }
        unmarkText()
    }
}

fileprivate func isWordChar(_ c: Character) -> Bool {
    !c.isWhitespace && !c.isPunctuation
}
