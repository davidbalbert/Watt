//
//  TextView+KeyBinding.swift
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
//        let point = layoutManager.position(forCharacterAt: selection.upperBound, affinity: selection.isEmpty ? selection.affinity : .upstream)
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
//        let point = layoutManager.position(forCharacterAt: selection.lowerBound, affinity: selection.isEmpty ? selection.affinity : .upstream)
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
        let viewport = convertToTextContainer(visibleRect)
        let point = layoutManager.position(forCharacterAt: selection.lowerBound, affinity: .downstream)

        scroll(CGPoint(x: 0, y: point.y - viewport.height/2))

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
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
//        let point = layoutManager.position(forCharacterAt: selection.upperBound, affinity: selection.isEmpty ? selection.affinity : .upstream)
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
//        let point = layoutManager.position(forCharacterAt: selection.lowerBound, affinity: selection.isEmpty ? selection.affinity : .upstream)
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
        if buffer.count < 2 {
            return
        }

        guard selection.isCaret || buffer.characters.distance(from: selection.lowerBound, to: selection.upperBound) == 2 else {
            return
        }

        let i: Buffer.Index
        let lineStart = buffer.lines.index(roundingDown: selection.lowerBound)

        if selection.isRange {
            i = selection.lowerBound
        } else if lineStart == selection.lowerBound {
            i = lineStart
        } else if selection.lowerBound == buffer.endIndex {
            i = buffer.index(selection.lowerBound, offsetBy: -2)
        } else {
            i = buffer.index(before: selection.lowerBound)
        }

        let j = buffer.index(after: i)
        let c1 = buffer[i]
        let c2 = buffer[j]

        replaceSubrange(i..<buffer.index(after: j), with: String(c2) + String(c1))

        let anchor = buffer.index(fromOldIndex: i)
        let head = buffer.index(anchor, offsetBy: 2)
        layoutManager.selection = Selection(anchor: anchor, head: head)
    }

    // Swap two words, and select them at the end. If there's
    // a selection that covers exactly two words, swap them.
    // If there's a caret, expand outwards to find the words to
    // swap. If we're in leading or trailing whitespace, there's
    // nothing to swap. If we're in the last word of the document,
    // swap that, plus the previous word. If we're in whitespace
    // between two words, swap those. Otherwise swap the word we're
    // in and the next word.
    override func transposeWords(_ sender: Any?) {
        if buffer.isEmpty {
            return
        }

        let word1: Range<Buffer.Index>
        let word2: Range<Buffer.Index>

        if selection.isRange {
            guard let (w1, w2) = boundsForTransposeWords(exactlyCoveredBy: selection.range, in: buffer) else {
                return
            }

            word1 = w1
            word2 = w2
        } else {
            guard let (w1, w2) = boundsForTransposeWords(containing: selection.lowerBound, in: buffer) else {
                return
            }

            word1 = w1
            word2 = w2
        }

        var b = AttributedRope.Builder()
        b.push(buffer[word2])
        b.push(buffer[word1.upperBound..<word2.lowerBound])
        b.push(buffer[word1])

        replaceSubrange(word1.lowerBound..<word2.upperBound, with: b.build())

        let anchor = buffer.index(fromOldIndex: word1.lowerBound)
        let head = buffer.index(fromOldIndex: word2.upperBound)

        layoutManager.selection = Selection(anchor: anchor, head: head)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    // MARK: - Selection

    override func selectAll(_ sender: Any?) {
        discardMarkedText()

        if buffer.isEmpty {
            updateInsertionPointTimer()
            return
        }

        layoutManager.selection = Selection(anchor: buffer.startIndex, head: buffer.endIndex)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
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

fileprivate func boundsForTransposeWords(exactlyCoveredBy range: Range<Buffer.Index>, in buffer: Buffer) -> (Range<Buffer.Index>, Range<Buffer.Index>)? {
    guard wordStartsAt(range.lowerBound, in: buffer) && wordEndsAt(range.upperBound, in: buffer) else {
        return nil
    }

    let limit = range.upperBound
    
    let start1 = range.lowerBound
    var i = start1

    while i < limit && isWordChar(buffer[i]) {
        i = buffer.index(after: i)
    }
    if i == limit { return nil }
    let end1 = i

    while i < limit && !isWordChar(buffer[i]) {
        i = buffer.index(after: i)
    }
    if i == limit { return nil }
    let start2 = i

    while i < limit && isWordChar(buffer[i]) {
        i = buffer.index(after: i)
    }
    if i < limit { return nil }
    let end2 = i

    return (start1..<end1, start2..<end2)
}

fileprivate func boundsForTransposeWords(containing position: Buffer.Index, in buffer: Buffer) -> (Range<Buffer.Index>, Range<Buffer.Index>)? {
    if buffer.isEmpty {
        return nil
    }

    // if we're in a word or at the end, go backwards until we find the end of a word
    // if we're in whitespace, go forward until we find the start of a word

    if position == buffer.endIndex && !isWordChar(buffer.characters.last!) {
        return nil
    }
    if position == buffer.startIndex && !isWordChar(buffer.characters.first!) {
        return nil
    }

    let word: Range<Buffer.Index>
    if position == buffer.endIndex {
        assert(isWordChar(buffer.characters.last!))
        word = boundsForWord(containing: buffer.index(before: buffer.endIndex), in: buffer)
    } else if isWordChar(buffer[position]) {
        word = boundsForWord(containing: position, in: buffer)
    } else {
        // we're in whitespace, so search forward for the next word
        var i = position
        while i < buffer.endIndex && !isWordChar(buffer[i]) {
            i = buffer.index(after: i)
        }

        if i == buffer.endIndex && position > buffer.startIndex && isWordChar(buffer[buffer.index(before: position)]) {
            // a special case, we're in trailing whitespace, but the character right before where we started is
            // a word, so we'll transpose that word with the one previous.
            word = boundsForWord(containing: buffer.index(before: position), in: buffer)
        } else if i == buffer.endIndex {
            // we're in trailing whitespace, and there's nothing to transpose
            return nil
        } else {
            // we found a word searching forward
            word = boundsForWord(containing: i, in: buffer)
        }
    }

    // if we started in whitespace, we're word2, and we need
    // to search backwards for word1. We treat being at the
    // start of a word as if we were in the whitespace before.
    if position == buffer.endIndex || wordStartsAt(position, in: buffer) || !isWordChar(buffer[position]) {
        if position == buffer.endIndex {
            assert(isWordChar(buffer.characters.last!))
        }

        let word2 = word
        var i = word2.lowerBound
        while i > buffer.startIndex {
            let prev = buffer.index(before: i)
            if isWordChar(buffer[prev]) {
                break
            }
            i = prev
        }

        if i == buffer.startIndex && isWordChar(buffer[position]) {
            // There was no previous word, but we were at the beginning
            // of a word, so we can search fowards instead. Just
            // fall through
        } else if i == buffer.startIndex {
            // there was a single word, so there's nothing to transpose
            return nil
        } else {
            // we found a word searching backwards
            let word1 = boundsForWord(containing: buffer.index(before: i), in: buffer)

            return (word1, word2)
        }
    }

    // We started in the middle of a word (or at the beginning
    // of the first word). We need to figure out if we're
    // word1 or word2. First we assume we're the first word, which
    // is most common, and we search forwards for the second word
    var i = word.upperBound
    while i < buffer.endIndex && !isWordChar(buffer[i]) {
        i = buffer.index(after: i)
    }

    // the more common case. word is the first word, and
    // i is pointing at the beginning of the second word
    if i < buffer.endIndex {
        let word1 = word
        let word2 = boundsForWord(containing: i, in: buffer)

        return (word1, word2)
    }

    // we didn't find a word going forward, so, now we assume
    // we're the second word, and we search backwards. This is
    // uncommon.
    let word2 = word
    i = word2.lowerBound
    while i > buffer.startIndex {
        let prev = buffer.index(before: i)
        if isWordChar(buffer[prev]) {
            break
        }
        i = prev
    }

    // there was a single word, so there's nothing to transpose
    if i == buffer.startIndex { return nil }

    let word1 = boundsForWord(containing: buffer.index(before: i), in: buffer)

    return (word1, word2)
}

fileprivate func boundsForWord(containing position: Buffer.Index, in buffer: Buffer) -> Range<Buffer.Index> {
    precondition(position < buffer.endIndex && isWordChar(buffer[position]))

    // search backwards for the start of the word
    var start = position
    while start > buffer.startIndex {
        let prev = buffer.index(before: start)
        if !isWordChar(buffer[prev]) {
            break
        }
        start = prev
    }

    // search forwards for the end of the word
    var end = position
    while end < buffer.endIndex && isWordChar(buffer[end]) {
        end = buffer.index(after: end)
    }

    return start..<end
}

fileprivate func wordStartsAt(_ i: Buffer.Index, in buffer: Buffer) -> Bool {
    if buffer.isEmpty || i == buffer.endIndex {
        return false
    }

    if i == buffer.startIndex {
        return isWordChar(buffer[i])
    }

    let prev = buffer.index(before: i)
    return !isWordChar(buffer[prev]) && isWordChar(buffer[i])
}

fileprivate func wordEndsAt(_ i: Buffer.Index, in buffer: Buffer) -> Bool {
    if buffer.isEmpty || i == buffer.startIndex {
        return false
    }

    if i == buffer.endIndex {
        return isWordChar(buffer.characters.last!)
    }

    let prev = buffer.index(before: i)
    return isWordChar(buffer[prev]) && !isWordChar(buffer[i])
}

fileprivate func isWordChar(_ c: Character) -> Bool {
    !c.isWhitespace && !c.isPunctuation
}
