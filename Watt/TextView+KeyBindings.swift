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

        // TODO: I don't think any of these calls to convertToTextContainer are correct.
        // We're using viewport.height down below, but the if there's a top or bottom
        // inset on the text container, the container will be shorter than the viewport.
        // I'm not sure the right way to handle this yet.
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

        scroll(CGPoint(x: 0, y: target.y - viewport.height/2))

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
        guard let line = layoutManager.line(forVerticalOffset: viewport.maxY) else {
            return
        }
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
        guard let selection = layoutManager.selection else {
            return
        }

        if buffer.count < 2 {
            return
        }

        guard selection.isEmpty || buffer.characters.distance(from: selection.lowerBound, to: selection.upperBound) == 2 else {
            return
        }

        let i: Buffer.Index

        if !selection.isEmpty {
            i = selection.lowerBound
        } else if selection.lowerBound == buffer.startIndex {
            i = buffer.startIndex
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

        let affinity: Selection.Affinity = head == buffer.endIndex ? .upstream : .downstream
        let xOffset = layoutManager.position(forCharacterAt: head, affinity: affinity).x
        layoutManager.selection = Selection(head: head, anchor: anchor, affinity: affinity, xOffset: xOffset)

        selectionLayer.setNeedsLayout()
        insertionPointLayer.setNeedsLayout()
        updateInsertionPointTimer()
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

        guard let selection = layoutManager.selection else {
            return
        }

        let word1: Range<Buffer.Index>
        let word2: Range<Buffer.Index>

        if !selection.isEmpty {
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

        let affinity: Selection.Affinity = head == buffer.endIndex ? .upstream : .downstream
        let xOffset = layoutManager.position(forCharacterAt: anchor, affinity: .upstream).x
        layoutManager.selection = Selection(head: head, anchor: anchor, affinity: affinity, xOffset: xOffset)

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

        // we're in trailing whitespace, so there's nothing
        // to transpose.
        if i == buffer.endIndex { return nil }
        word = boundsForWord(containing: i, in: buffer)
    }

    // if we started in whitespace, we're word2, and we need
    // to search backwards for word1.
    if position == buffer.endIndex || !isWordChar(buffer[position]) {
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

        // there was a single word, so there's nothing to transpose
        if i == buffer.startIndex { return nil }

        let word1 = boundsForWord(containing: buffer.index(before: i), in: buffer)

        return (word1, word2)
    }


    // We started in the middle of a word. We need to figure out
    // if we're word1 or word2. First we assume we're the first
    // word, which is most common, and we search forwards for
    // the second word
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
