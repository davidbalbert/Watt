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

        guard let line = layoutManager.line(containing: selection.upperBound) else {
            return
        }
        guard let frag = line.fragment(containing: selection.upperBound, affinity: .upstream) else {
            return
        }

        if selection.isEmpty && frag.range.upperBound == buffer.endIndex {
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

    override func moveToBeginningOfLine(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        guard let line = layoutManager.line(containing: selection.lowerBound) else {
            return
        }
        // Empty selections can have upstream affinity if they're at the end of a fragment,
        // and we need to know this to find the right one. 
        guard let frag = line.fragment(containing: selection.lowerBound, affinity: selection.isEmpty ? selection.affinity : .downstream) else {
            return
        }

        if selection.isEmpty && frag.range.lowerBound == selection.lowerBound {
            updateInsertionPointTimer()
            return
        }

        let head = frag.range.lowerBound
        let xOffset = layoutManager.position(forCharacterAt: head, affinity: .downstream).x
        layoutManager.selection = Selection(head: head, affinity: .downstream, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveToEndOfLine(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        guard let line = layoutManager.line(containing: selection.upperBound) else {
            return
        }
        guard let frag = line.fragment(containing: selection.upperBound, affinity: selection.isEmpty ? selection.affinity : .upstream) else {
            return
        }

        if selection.isEmpty && frag.range.upperBound == selection.upperBound {
            updateInsertionPointTimer()
            return
        }

        let hardBreak = buffer[frag.range].characters.last == "\n"
        let head = hardBreak ? buffer.index(before: frag.range.upperBound) : frag.range.upperBound
        let affinity: Selection.Affinity = hardBreak ? .downstream : .upstream

        let xOffset = layoutManager.position(forCharacterAt: head, affinity: affinity).x
        layoutManager.selection = Selection(head: head, affinity: affinity, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveToBeginningOfParagraph(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        let start = buffer.lines.index(roundingDown: selection.lowerBound)

        if selection.isEmpty && start == selection.lowerBound {
            updateInsertionPointTimer()
            return
        }

        let head = start
        let affinity: Selection.Affinity = head == buffer.endIndex ? .upstream : .downstream
        let xOffset = layoutManager.position(forCharacterAt: head, affinity: affinity).x
        layoutManager.selection = Selection(head: head, affinity: affinity, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveToEndOfParagraph(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.isEmpty && selection.upperBound == buffer.endIndex {
            updateInsertionPointTimer()
            return
        }

        let head: Buffer.Index
        let affinity: Selection.Affinity
        if selection.upperBound == buffer.endIndex {
            head = buffer.endIndex
            affinity = .upstream
        } else {
            let nextLineStart = buffer.lines.index(after: selection.upperBound)
            if nextLineStart == buffer.endIndex && buffer.characters.last != "\n" {
                head = buffer.endIndex
                affinity = .upstream
            } else {
                head = buffer.index(before: nextLineStart)
                affinity = .downstream
            }
        }

        assert(head == buffer.endIndex || buffer[head] == "\n")

        let xOffset = layoutManager.position(forCharacterAt: head, affinity: affinity).x
        layoutManager.selection = Selection(head: head, affinity: affinity, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()   
    }

    override func moveToEndOfDocument(_ sender: Any?) {
        if let selection = layoutManager.selection, selection.lowerBound == buffer.endIndex {
            updateInsertionPointTimer()
            return
        }

        let xOffset = layoutManager.position(forCharacterAt: buffer.endIndex, affinity: .upstream).x
        layoutManager.selection = Selection(head: buffer.endIndex, affinity: .upstream, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()   
    }

    override func moveToBeginningOfDocument(_ sender: Any?) {
        if let selection = layoutManager.selection, selection.lowerBound == buffer.startIndex {
            updateInsertionPointTimer()
            return
        }

        let affinity: Selection.Affinity = buffer.isEmpty ? .upstream : .downstream
        let xOffset = layoutManager.position(forCharacterAt: buffer.startIndex, affinity: affinity).x
        layoutManager.selection = Selection(head: buffer.startIndex, affinity: affinity, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func pageDown(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        let viewport = convertToTextContainer(visibleRect)
        let point = layoutManager.position(forCharacterAt: selection.upperBound, affinity: selection.isEmpty ? selection.affinity : .upstream)

        let target = CGPoint(
            x: selection.xOffset,
            y: point.y + viewport.height
        )

        guard let (head, affinity) = layoutManager.locationAndAffinity(interactingAt: target) else {
            return
        }

        layoutManager.selection = Selection(head: head, affinity: affinity, xOffset: selection.xOffset)

        scroll(CGPoint(x: 0, y: target.y - viewport.height/2))

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func pageUp(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        let viewport = convertToTextContainer(visibleRect)
        let point = layoutManager.position(forCharacterAt: selection.lowerBound, affinity: selection.isEmpty ? selection.affinity : .upstream)

        let target = CGPoint(
            x: selection.xOffset,
            y: point.y - viewport.height
        )

        guard let (head, affinity) = layoutManager.locationAndAffinity(interactingAt: target) else {
            return
        }

        layoutManager.selection = Selection(head: head, affinity: affinity, xOffset: selection.xOffset)

        scroll(CGPoint(x: 0, y: target.y - viewport.height/2))

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func centerSelectionInVisibleArea(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        let viewport = convertToTextContainer(visibleRect)
        let point = layoutManager.position(forCharacterAt: selection.lowerBound, affinity: .downstream)

        scroll(CGPoint(x: 0, y: point.y - viewport.height/2))

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }



    override func moveBackwardAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.head == buffer.startIndex {
            updateInsertionPointTimer()
            return
        }

        let head = buffer.index(before: selection.head)
        let xOffset = layoutManager.position(forCharacterAt: head, affinity: .downstream).x
        layoutManager.selection = Selection(head: head, anchor: selection.anchor, affinity: selection.affinity, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveForwardAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.head == buffer.endIndex {
            updateInsertionPointTimer()
            return
        }

        let head = buffer.index(after: selection.head)
        let xOffset = layoutManager.position(forCharacterAt: head, affinity: .downstream).x
        let affinity: Selection.Affinity = head == buffer.endIndex ? .upstream : .downstream
        layoutManager.selection = Selection(head: head, anchor: selection.anchor, affinity: affinity, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveWordForwardAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.head == buffer.endIndex {
            updateInsertionPointTimer()
            return
        }

        var head = selection.head
        while head < buffer.endIndex && isWordBoundary(buffer[head]) {
            head = buffer.index(after: head)
        }
        while head < buffer.endIndex && !isWordBoundary(buffer[head]) {
            head = buffer.index(after: head)
        }

        let affinity: Selection.Affinity = head == buffer.endIndex ? .upstream : .downstream

        let xOffset = layoutManager.position(forCharacterAt: head, affinity: affinity).x
        layoutManager.selection = Selection(head: head, anchor: selection.anchor, affinity: affinity, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveWordBackwardAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.head == buffer.startIndex {
            updateInsertionPointTimer()
            return
        }

        var head = selection.head
        while head > buffer.startIndex && isWordBoundary(buffer[buffer.index(before: head)]) {
            head = buffer.index(before: head)
        }
        while head > buffer.startIndex && !isWordBoundary(buffer[buffer.index(before: head)]) {
            head = buffer.index(before: head)
        }

        let xOffset = layoutManager.position(forCharacterAt: head, affinity: .downstream).x
        layoutManager.selection = Selection(head: head, anchor: selection.anchor, affinity: .downstream, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveUpAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        guard let line = layoutManager.line(containing: selection.head) else {
            return
        }
        guard let frag = line.fragment(containing: selection.head, affinity: selection.affinity) else {
            return
        }

        if frag.range.lowerBound == buffer.startIndex {
            let xOffset = layoutManager.position(forCharacterAt: buffer.startIndex, affinity: .downstream).x
            layoutManager.selection = Selection(head: buffer.startIndex, anchor: selection.anchor, affinity: .downstream, xOffset: xOffset)
        } else {
            let pointInLine = CGPoint(
                x: selection.xOffset,
                y: frag.alignmentFrame.minY - 0.0001
            )
            let point = layoutManager.convert(pointInLine, from: line)
            guard let (head, affinity) = layoutManager.locationAndAffinity(interactingAt: point) else {
                return
            }

            layoutManager.selection = Selection(head: head, anchor: selection.anchor, affinity: affinity, xOffset: selection.xOffset)
        }
    
        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveDownAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        guard let line = layoutManager.line(containing: selection.head) else {
            return
        }
        guard let frag = line.fragment(containing: selection.head, affinity: selection.affinity) else {
            return
        }

        if frag.range.upperBound == buffer.endIndex {
            let xOffset = layoutManager.position(forCharacterAt: buffer.endIndex, affinity: .upstream).x
            layoutManager.selection = Selection(head: buffer.endIndex, anchor: selection.anchor, affinity: .upstream, xOffset: xOffset)
        } else {
            let pointInLine = CGPoint(
                x: selection.xOffset,
                y: frag.alignmentFrame.maxY
            )
            let point = layoutManager.convert(pointInLine, from: line)
            guard let (head, affinity) = layoutManager.locationAndAffinity(interactingAt: point) else {
                return
            }

            layoutManager.selection = Selection(head: head, anchor: selection.anchor, affinity: affinity, xOffset: selection.xOffset)
        }

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveToBeginningOfLineAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        guard let line = layoutManager.line(containing: selection.lowerBound) else {
            return
        }
        guard let frag = line.fragment(containing: selection.lowerBound, affinity: selection.isEmpty ? selection.affinity : .downstream) else {
            return
        }

        if frag.range.lowerBound == selection.lowerBound {
            updateInsertionPointTimer()
            return
         }

        let head = frag.range.lowerBound
        // special case: if selection.head == selection.upperBound, we want to
        // expand the selection to the end of the line, rather than flipping it
        // around the anchor, so the anchor is always selection.upperBound, rather
        // than selection.anchor.
        let anchor = selection.upperBound
        let xOffset = layoutManager.position(forCharacterAt: head, affinity: .downstream).x
        layoutManager.selection = Selection(head: head, anchor: anchor, affinity: .downstream, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveToEndOfLineAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        guard let line = layoutManager.line(containing: selection.upperBound) else {
            return
        }
        guard let frag = line.fragment(containing: selection.upperBound, affinity: selection.isEmpty ? selection.affinity : .upstream) else {
            return
        }

        if frag.range.upperBound == selection.upperBound {
            updateInsertionPointTimer()
            return
        }

        let hardBreak = buffer[frag.range].characters.last == "\n"
        let head = hardBreak ? buffer.index(before: frag.range.upperBound) : frag.range.upperBound
        let affinity: Selection.Affinity = hardBreak ? .downstream : .upstream
        let anchor = selection.lowerBound

        let xOffset = layoutManager.position(forCharacterAt: head, affinity: affinity).x
        layoutManager.selection = Selection(head: head, anchor: anchor, affinity: affinity, xOffset: xOffset)

        print(head, anchor)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveToBeginningOfParagraphAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        let start = buffer.lines.index(roundingDown: selection.lowerBound)

        if start == selection.lowerBound {
            updateInsertionPointTimer()
            return
        }

        let head = start
        let anchor = selection.upperBound
        let affinity: Selection.Affinity = head == buffer.endIndex ? .upstream : .downstream
        let xOffset = layoutManager.position(forCharacterAt: head, affinity: affinity).x
        layoutManager.selection = Selection(head: head, anchor: anchor, affinity: affinity, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveToEndOfParagraphAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.upperBound == buffer.endIndex {
            updateInsertionPointTimer()
            return
        }

        let nextLineStart = buffer.lines.index(after: selection.upperBound)
        if nextLineStart == buffer.endIndex && buffer.characters.last != "\n" {
            let head = buffer.endIndex
            let anchor = selection.lowerBound
            let xOffset = layoutManager.position(forCharacterAt: head, affinity: .upstream).x
            layoutManager.selection = Selection(head: head, anchor: anchor, affinity: .upstream, xOffset: xOffset)
        } else {
            let head = buffer.index(before: nextLineStart)
            let anchor = selection.lowerBound
            let xOffset = layoutManager.position(forCharacterAt: head, affinity: .downstream).x
            layoutManager.selection = Selection(head: head, anchor: anchor, affinity: .downstream, xOffset: xOffset)
        }

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveToEndOfDocumentAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.upperBound == buffer.endIndex {
            updateInsertionPointTimer()
            return
        }

        let head = buffer.endIndex
        let anchor = selection.lowerBound
        let xOffset = layoutManager.position(forCharacterAt: head, affinity: .upstream).x
        layoutManager.selection = Selection(head: head, anchor: anchor, affinity: .upstream, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveToBeginningOfDocumentAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.lowerBound == buffer.startIndex {
            updateInsertionPointTimer()
            return
        }

        let head = buffer.startIndex
        let anchor = selection.upperBound
        let affinity: Selection.Affinity = buffer.isEmpty ? .upstream : .downstream
        let xOffset = layoutManager.position(forCharacterAt: head, affinity: affinity).x
        layoutManager.selection = Selection(head: head, anchor: anchor, affinity: affinity, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func pageDownAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        let viewport = convertToTextContainer(visibleRect)
        let point = layoutManager.position(forCharacterAt: selection.upperBound, affinity: selection.isEmpty ? selection.affinity : .upstream)

        let target = CGPoint(
            x: selection.xOffset,
            y: point.y + viewport.height
        )

        guard let (head, affinity) = layoutManager.locationAndAffinity(interactingAt: target) else {
            return
        }

        layoutManager.selection = Selection(head: head, anchor: selection.lowerBound, affinity: affinity, xOffset: selection.xOffset)

        scroll(CGPoint(x: 0, y: target.y - visiviewportbleRect.height/2))

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func pageUpAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        let viewport = convertToTextContainer(visibleRect)
        let point = layoutManager.position(forCharacterAt: selection.lowerBound, affinity: selection.isEmpty ? selection.affinity : .upstream)

        let target = CGPoint(
            x: selection.xOffset,
            y: point.y - viewport.height
        )

        guard let (head, affinity) = layoutManager.locationAndAffinity(interactingAt: target) else {
            return
        }

        layoutManager.selection = Selection(head: head, anchor: selection.upperBound, affinity: affinity, xOffset: selection.xOffset)

        scroll(CGPoint(x: 0, y: target.y - viewport.height/2))

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveParagraphForwardAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.upperBound == buffer.endIndex {
            updateInsertionPointTimer()
            return
        }

        let nextLineStart = buffer.lines.index(after: selection.upperBound)
        if nextLineStart == buffer.endIndex && buffer.characters.last != "\n" {
            let head = buffer.endIndex
            let anchor = selection.lowerBound
            let xOffset = layoutManager.position(forCharacterAt: head, affinity: .upstream).x
            layoutManager.selection = Selection(head: head, anchor: anchor, affinity: .upstream, xOffset: xOffset)
        } else {
            let head = buffer.index(before: nextLineStart)
            let anchor = selection.lowerBound
            let xOffset = layoutManager.position(forCharacterAt: head, affinity: .downstream).x
            layoutManager.selection = Selection(head: head, anchor: anchor, affinity: .downstream, xOffset: xOffset)
        }

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
    }

    override func moveParagraphBackwardAndModifySelection(_ sender: Any?) {
        guard let selection = layoutManager.selection else {
            return
        }

        if selection.lowerBound == buffer.startIndex {
            updateInsertionPointTimer()
            return
        }

        let head = buffer.lines.index(roundingDown: selection.lowerBound)
        let anchor = selection.upperBound
        let affinity: Selection.Affinity = head == buffer.endIndex ? .upstream : .downstream
        let xOffset = layoutManager.position(forCharacterAt: head, affinity: affinity).x
        layoutManager.selection = Selection(head: head, anchor: anchor, affinity: affinity, xOffset: xOffset)

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

    override func moveRightAndModifySelection(_ sender: Any?) {
        moveForwardAndModifySelection(sender)
    }

    override func moveLeftAndModifySelection(_ sender: Any?) {
        moveBackwardAndModifySelection(sender)
    }

    override func moveWordRightAndModifySelection(_ sender: Any?) {
        moveWordForwardAndModifySelection(sender)
    }

    override func moveWordLeftAndModifySelection(_ sender: Any?) {
        moveWordBackwardAndModifySelection(sender)
    }



    override func moveToLeftEndOfLine(_ sender: Any?) {
        moveToBeginningOfLine(self)
    }

    override func moveToRightEndOfLine(_ sender: Any?) {
        moveToEndOfLine(self)
    }

    override func moveToLeftEndOfLineAndModifySelection(_ sender: Any?) {
        moveToBeginningOfLineAndModifySelection(sender)
    }

    override func moveToRightEndOfLineAndModifySelection(_ sender: Any?) {
        moveToEndOfLineAndModifySelection(sender)
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
        guard let line = layoutManager.line(forVerticalOffset: viewport.minY - 0.0001) else {
            return
        }
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
        guard let line = layoutManager.line(forVerticalOffset: origin.y + viewport.height) else {
            return
        }
        guard let frag = line.fragment(forVerticalOffset: origin.y + viewport.height) else {
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

    // MARK: - Selection

    override func selectAll(_ sender: Any?) {
        discardMarkedText()

        if buffer.isEmpty {
            updateInsertionPointTimer()
            return
        }

        let xOffset = layoutManager.position(forCharacterAt: buffer.startIndex, affinity: .downstream).x
        layoutManager.selection = Selection(head: buffer.endIndex, anchor: buffer.startIndex, affinity: .downstream, xOffset: xOffset)

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
