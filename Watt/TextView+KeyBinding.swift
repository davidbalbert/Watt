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
    // KeyBinding Inspector: https://github.com/davidbalbert/KeyBinding-Inspector

    func moveSelection(_ movement: Movement) {
        selection = SelectionNavigator(selection).selection(moving: movement, dataSource: layoutManager)
    }

    func extendSelection(_ movement: Movement) {
        selection = SelectionNavigator(selection).selection(extending: movement, dataSource: layoutManager)
    }

    // MARK: Selection movement and scrolling

    override func moveForward(_ sender: Any?) {
        moveSelection(.right)
        scrollSelectionToVisible()
    }

    override func moveRight(_ sender: Any?) {
        moveSelection(.right)
        scrollSelectionToVisible()
    }

    override func moveBackward(_ sender: Any?) {
        moveSelection(.left)
        scrollSelectionToVisible()
    }

    override func moveLeft(_ sender: Any?) {
        moveSelection(.left)
        scrollSelectionToVisible()
    }

    override func moveUp(_ sender: Any?) {
        moveSelection(.up)
        scrollSelectionToVisible()
    }

    override func moveDown(_ sender: Any?) {
        moveSelection(.down)
        scrollSelectionToVisible()
    }

    override func moveWordForward(_ sender: Any?) {
        moveSelection(.wordRight)
        scrollSelectionToVisible()
    }

    override func moveWordBackward(_ sender: Any?) {
        moveSelection(.wordLeft)
        scrollSelectionToVisible()
    }

    override func moveToBeginningOfLine(_ sender: Any?) {
        moveSelection(.beginningOfLine)
        scrollSelectionToVisible()
    }

    override func moveToEndOfLine(_ sender: Any?) {
        moveSelection(.endOfLine)
        scrollSelectionToVisible()
    }

    override func moveToBeginningOfParagraph(_ sender: Any?) {
        moveSelection(.beginningOfParagraph)
        scrollSelectionToVisible()
    }

    override func moveToEndOfParagraph(_ sender: Any?) {
        moveSelection(.endOfParagraph)
        scrollSelectionToVisible()
    }

    override func moveToEndOfDocument(_ sender: Any?) {
        moveSelection(.endOfDocument)
        scrollSelectionToVisible()
    }

    override func moveToBeginningOfDocument(_ sender: Any?) {
        moveSelection(.beginningOfDocument)
        scrollSelectionToVisible()
    }

    override func pageDown(_ sender: Any?) {
        moveSelection(.pageDown)
        centerSelectionHead()
    }

    override func pageUp(_ sender: Any?) {
        moveSelection(.pageUp)
        centerSelectionHead()
    }

    override func centerSelectionInVisibleArea(_ sender: Any?) {
        if selection.isCaret {
            guard let rect = layoutManager.caretRect(for: selection.head, affinity: selection.affinity) else {
                return
            }
            scrollToCenter(rect)
            return
        }

        let r1 = layoutManager.caretRect(for: selection.lowerBound, affinity: .downstream)
        let r2 = layoutManager.caretRect(for: selection.upperBound, affinity: .upstream)
        guard let r1, let r2 else {
            return
        }
        let rect = r1.union(r2)

        let viewport = textContainerVisibleRect

        if rect.height < viewport.height {
            scrollToCenter(rect)
        } else if viewport.minY < rect.minY {
            let target = r1.origin
            scroll(convertFromTextContainer(target))
        } else if rect.maxY < viewport.maxY {
            let target = CGPoint(x: r2.minX, y: r2.maxY - viewport.height)
            scroll(convertFromTextContainer(target))
        }
    }



    override func moveBackwardAndModifySelection(_ sender: Any?) {
        extendSelection(.left)
        scrollSelectionToVisible()
    }

    override func moveForwardAndModifySelection(_ sender: Any?) {
        extendSelection(.right)
        scrollSelectionToVisible()
    }

    override func moveWordForwardAndModifySelection(_ sender: Any?) {
        extendSelection(.wordRight)
        scrollSelectionToVisible()
    }

    override func moveWordBackwardAndModifySelection(_ sender: Any?) {
        extendSelection(.wordLeft)
        scrollSelectionToVisible()
    }

    override func moveUpAndModifySelection(_ sender: Any?) {
        extendSelection(.up)
        scrollSelectionToVisible()
    }

    override func moveDownAndModifySelection(_ sender: Any?) {
        extendSelection(.down)
        scrollSelectionToVisible()
    }



    override func moveToBeginningOfLineAndModifySelection(_ sender: Any?) {
        extendSelection(.beginningOfLine)
        scrollSelectionToVisible()
    }

    override func moveToEndOfLineAndModifySelection(_ sender: Any?) {
        extendSelection(.endOfLine)
        scrollSelectionToVisible()
    }

    override func moveToBeginningOfParagraphAndModifySelection(_ sender: Any?) {
        extendSelection(.beginningOfParagraph)
        scrollSelectionToVisible()
    }

    override func moveToEndOfParagraphAndModifySelection(_ sender: Any?) {
        extendSelection(.endOfParagraph)
        scrollSelectionToVisible()
    }

    override func moveToEndOfDocumentAndModifySelection(_ sender: Any?) {
        extendSelection(.endOfDocument)
        scrollSelectionToVisible()
    }

    override func moveToBeginningOfDocumentAndModifySelection(_ sender: Any?) {
        extendSelection(.beginningOfDocument)
        scrollSelectionToVisible()
    }

    override func pageDownAndModifySelection(_ sender: Any?) {
        extendSelection(.pageDown)
        centerSelectionHead()
    }

    override func pageUpAndModifySelection(_ sender: Any?) {
        extendSelection(.pageUp)
        centerSelectionHead()
    }

    override func moveParagraphForwardAndModifySelection(_ sender: Any?) {
        extendSelection(.paragraphForward)
        scrollSelectionToVisible()
    }

    override func moveParagraphBackwardAndModifySelection(_ sender: Any?) {
        extendSelection(.paragraphBackward)
        scrollSelectionToVisible()
    }



    override func moveWordRight(_ sender: Any?) {
        moveSelection(.wordRight)
        scrollSelectionToVisible()
    }

    override func moveWordLeft(_ sender: Any?) {
        moveSelection(.wordLeft)
        scrollSelectionToVisible()
    }

    override func moveRightAndModifySelection(_ sender: Any?) {
        extendSelection(.right)
        scrollSelectionToVisible()
    }

    override func moveLeftAndModifySelection(_ sender: Any?) {
        extendSelection(.left)
        scrollSelectionToVisible()
    }

    override func moveWordRightAndModifySelection(_ sender: Any?) {
        extendSelection(.wordRight)
        scrollSelectionToVisible()
    }

    override func moveWordLeftAndModifySelection(_ sender: Any?) {
        extendSelection(.wordLeft)
        scrollSelectionToVisible()
    }



    override func moveToLeftEndOfLine(_ sender: Any?) {
        moveSelection(.beginningOfLine)
        scrollSelectionToVisible()
    }

    override func moveToRightEndOfLine(_ sender: Any?) {
        moveSelection(.endOfLine)
        scrollSelectionToVisible()
    }

    override func moveToLeftEndOfLineAndModifySelection(_ sender: Any?) {
        extendSelection(.beginningOfLine)
        scrollSelectionToVisible()
    }

    override func moveToRightEndOfLineAndModifySelection(_ sender: Any?) {
        extendSelection(.endOfLine)
        scrollSelectionToVisible()
    }



    override func scrollPageUp(_ sender: Any?) {
        let viewport = textContainerVisibleRect
        let point = CGPoint(
            x: textContainerScrollOffset.x,
            y: viewport.minY - viewport.height
        )

        animator().scroll(convertFromTextContainer(point))
    }

    override func scrollPageDown(_ sender: Any?) {
        let viewport = textContainerVisibleRect
        let point = CGPoint(
            x: textContainerScrollOffset.x,
            y: viewport.maxY
        )

        animator().scroll(convertFromTextContainer(point))
    }

    override func scrollLineUp(_ sender: Any?) {
        let viewport = textContainerVisibleRect

        // Goal: find the first fragment that's fully above the viewport and scroll it
        // in to view. It would be simpler to find the first fragment that contains
        // viewport.minY - 0.0001, but if we did that, and viewport.minY bisected a
        // fragment, we'd just scroll the rest of that fragment into view, which doesn't
        // feel as good.
        let firstLine = layoutManager.line(forVerticalOffset: viewport.minY)
        guard let firstFrag = firstLine.fragment(forVerticalOffset: viewport.minY) else {
            return
        }

        let i = firstFrag.range.lowerBound

        let targetLine: Line
        let targetFrag: LineFragment
        if i == buffer.startIndex {
            targetLine = firstLine
            targetFrag = firstFrag
        } else {
            let j = buffer.index(before: i)
            targetLine = layoutManager.line(containing: j)
            guard let f = targetLine.fragment(containing: j, affinity: .downstream) else {
                return
            }
            targetFrag = f
        }

        let frame = layoutManager.convert(targetFrag.alignmentFrame, from: targetLine)

        let target = CGPoint(
            x: textContainerScrollOffset.x,
            y: frame.minY
        )

        // Not sure why this isn't animating. I thought it might have been due to only
        // scrolling by a short distance, but I tried adding longer distances and it
        // still didn't scroll. But other calls in this file are definitely animating,
        // so something else is going on. I'll have to look into it.
        animator().scroll(convertFromTextContainer(target))
    }

    override func scrollLineDown(_ sender: Any?) {
        let viewport = textContainerVisibleRect

        // Same goal and logic as scrollLineUp. See comment there for more.
        let lastLine = layoutManager.line(forVerticalOffset: viewport.maxY - 0.0001)
        guard let lastFrag = lastLine.fragment(forVerticalOffset: viewport.maxY - 0.0001) else {
            return
        }

        let i = lastFrag.range.upperBound

        let targetLine = layoutManager.line(containing: i)
        guard let targetFrag = targetLine.fragment(containing: i, affinity: i == buffer.endIndex ? .upstream : .downstream) else {
            return
        }

        let frame = layoutManager.convert(targetFrag.alignmentFrame, from: targetLine)
        let target = CGPoint(
            x: textContainerScrollOffset.x,
            y: frame.maxY - viewport.height
        )

        // not sure why this isn't animating? Maybe it doesn't animate for short changes?
        animator().scroll(convertFromTextContainer(target))
    }



    // TODO: without better height estimates, or a full asyncronous layout pass,
    // scrollToBeginningOfDocument and scrollToEndOfDocument often don't actually
    // put you at the beginning or the end.
    //
    // I wonder if there's another way around this.
    override func scrollToBeginningOfDocument(_ sender: Any?) {
        let point = CGPoint(
            x: textContainerScrollOffset.x,
            y: 0
        )

        animator().scroll(convertFromTextContainer(point))
    }

    override func scrollToEndOfDocument(_ sender: Any?) {
        let viewport = textContainerVisibleRect
        let point = CGPoint(
            x: textContainerScrollOffset.x,
            y: layoutManager.contentHeight - viewport.height
        )

        animator().scroll(convertFromTextContainer(point))
    }


    // MARK: - Graphical Element transposition

    override func transpose(_ sender: Any?) {
        guard let (i, j) = Transposer.indicesForTranspose(inSelectedRange: selection.range, dataSource: buffer) else {
            return
        }

        replaceSubrange((i...j).relative(to: buffer.text), with: String(buffer[j]) + String(buffer[i]))

        let anchor = buffer.index(fromOldIndex: i)
        let head = buffer.index(anchor, offsetBy: 2)
        selection = Selection(anchor: anchor, head: head, granularity: .character)
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

        selection = Selection(anchor: anchor, head: head, granularity: .character)
    }


    // MARK: - Selections

    override func selectAll(_ sender: Any?) {
        discardMarkedText()

        if buffer.isEmpty {
            updateInsertionPointTimer()
            return
        }

        selection = Selection(anchor: buffer.startIndex, head: buffer.endIndex, granularity: .character)
    }

    override func selectParagraph(_ sender: Any?) {

    }

    override func selectLine(_ sender: Any?) {

    }

    override func selectWord(_ sender: Any?) {

    }


    // MARK: - Insertions and Indentations

    override func indent(_ sender: Any?) {

    }

    override func insertTab(_ sender: Any?) {
        replaceSubrange(selection.range, with: AttributedRope("\t", attributes: typingAttributes))
        unmarkText()
    }

    override func insertBacktab(_ sender: Any?) {

    }

    override func insertNewline(_ sender: Any?) {
        replaceSubrange(selection.range, with: AttributedRope("\n", attributes: typingAttributes))
        unmarkText()
    }

    override func insertParagraphSeparator(_ sender: Any?) {

    }

    override func insertNewlineIgnoringFieldEditor(_ sender: Any?) {
        insertNewline(sender)
    }

    override func insertTabIgnoringFieldEditor(_ sender: Any?) {
        insertTab(sender)
    }

    override func insertLineBreak(_ sender: Any?) {

    }

    override func insertContainerBreak(_ sender: Any?) {

    }

    override func insertSingleQuoteIgnoringSubstitution(_ sender: Any?) {

    }

    override func insertDoubleQuoteIgnoringSubstitution(_ sender: Any?) {

    }


    // MARK: - Case changes

    override func changeCaseOfLetter(_ sender: Any?) {

    }

    override func uppercaseWord(_ sender: Any?) {

    }

    override func lowercaseWord(_ sender: Any?) {

    }

    override func capitalizeWord(_ sender: Any?) {

    }


    // MARK: - Deletions

    override func deleteForward(_ sender: Any?) {
        let range = SelectionNavigator(selection).rangeToDelete(movement: .right, dataSource: layoutManager)
        replaceSubrange(range, with: "")
        unmarkText()
    }

    override func deleteBackward(_ sender: Any?) {
        let range = SelectionNavigator(selection).rangeToDelete(movement: .left, dataSource: layoutManager)
        replaceSubrange(range, with: "")
        unmarkText()
    }

    override func deleteBackwardByDecomposingPreviousCharacter(_ sender: Any?) {
        let (range, s) = SelectionNavigator(selection).replacementForDeleteBackwardsByDecomposing(dataSource: layoutManager)
        replaceSubrange(range, with: AttributedRope(s, attributes: typingAttributes))
        unmarkText()
    }

    override func deleteWordForward(_ sender: Any?) {
        let range = SelectionNavigator(selection).rangeToDelete(movement: .wordRight, dataSource: layoutManager)
        replaceSubrange(range, with: "")
        unmarkText()
    }

    override func deleteWordBackward(_ sender: Any?) {
        let range = SelectionNavigator(selection).rangeToDelete(movement: .wordLeft, dataSource: layoutManager)
        replaceSubrange(range, with: "")
        unmarkText()
    }

    // Follow Xcode's lead and make deleteToBeginningOfLine: behave like deleteToBeginningOfParagraph:.
    // I imagine this is because StandardKeyBinding.dict only includes deleteToBeginningOfLine: and
    // deleteToEndOfPargraph: and in a text editor it's more useful for Command-Delete to delete to
    // the beginning of the line, not the line fragment.
    //
    // Perhaps this would be a good place for some sort of preference in the future.
    override func deleteToBeginningOfLine(_ sender: Any?) {
        let range = SelectionNavigator(selection).rangeToDelete(movement: .beginningOfParagraph, dataSource: layoutManager)
        replaceSubrange(range, with: "")
        unmarkText()
    }

    override func deleteToEndOfLine(_ sender: Any?) {
        let range = SelectionNavigator(selection).rangeToDelete(movement: .endOfLine, dataSource: layoutManager)
        replaceSubrange(range, with: "")
        unmarkText()
    }

    override func deleteToBeginningOfParagraph(_ sender: Any?) {
        let range = SelectionNavigator(selection).rangeToDelete(movement: .beginningOfParagraph, dataSource: layoutManager)
        replaceSubrange(range, with: "")
        unmarkText()
    }

    override func deleteToEndOfParagraph(_ sender: Any?) {
        let range = SelectionNavigator(selection).rangeToDelete(movement: .endOfParagraph, dataSource: layoutManager)
        replaceSubrange(range, with: "")
        unmarkText()
    }



    override func yank(_ sender: Any?) {

    }


    // MARK: - Completion

    override func complete(_ sender: Any?) {

    }


    // MARK: - Mark/Point manipulation
    
    override func setMark(_ sender: Any?) {

    }

    override func deleteToMark(_ sender: Any?) {

    }

    override func selectToMark(_ sender: Any?) {

    }

    override func swapWithMark(_ sender: Any?) {

    }


    // MARK: - Cancellation

    override func cancelOperation(_ sender: Any?) {

    }


    // MARK: - Writing Direction

    override func makeBaseWritingDirectionNatural(_ sender: Any?) {

    }

    override func makeBaseWritingDirectionLeftToRight(_ sender: Any?) {

    }

    override func makeBaseWritingDirectionRightToLeft(_ sender: Any?) {

    }


    override func makeTextWritingDirectionNatural(_ sender: Any?) {

    }

    override func makeTextWritingDirectionLeftToRight(_ sender: Any?) {

    }

    override func makeTextWritingDirectionRightToLeft(_ sender: Any?) {

    }


    // MARK: - Quick Look

    override func quickLookPreviewItems(_ sender: Any?) {

    }
}
