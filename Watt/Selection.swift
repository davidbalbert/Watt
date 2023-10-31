//
//  Selection.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import Foundation

protocol SelectionLayoutDataSource {
    func lineFragmentRange(containing index: Buffer.Index, affinity: Selection.Affinity) -> Range<Buffer.Index>?

    // returns the index that's closest to xOffset (i.e. xOffset gets rounded to the nearest character)
    func index(forHorizontalOffset xOffset: CGFloat, inLineFragmentContaining index: Buffer.Index, affinity: Selection.Affinity) -> Buffer.Index?

    // point is in text container coordinates
    func point(forCharacterAt index: Buffer.Index, affinity: Selection.Affinity) -> CGPoint
}

struct Selection: Equatable {
    enum Affinity: Equatable {
        case upstream
        case downstream
    }

    enum Granularity {
        case character
        case word
        case line        
    }

    let range: Range<Buffer.Index>
    // For caret, determines which side of a line wrap the caret is on.
    // For range, determins which the end is head, and which end is the anchor.
    let affinity: Affinity
    let xOffset: CGFloat? // in text container coordinates
    let markedRange: Range<Rope.Index>?

    init(caretAt index: Buffer.Index, affinity: Affinity, xOffset: CGFloat? = nil, markedRange: Range<Rope.Index>? = nil) {
        self.init(range: index..<index, affinity: affinity, xOffset: xOffset, markedRange: markedRange)
    }

    // xOffset still needs to be maintained while selecting for a specific special case:
    // If we're moving up from within the first fragment to the beginning of the document
    // or moving down from the within the last fragment to the end of the document, we want
    // to maintain our xOffset so that when we move back in the opposite vertical direction,
    // we move by one line fragment and also jump horizontally to our xOffset
    init(anchor: Buffer.Index, head: Buffer.Index, xOffset: CGFloat? = nil, markedRange: Range<Rope.Index>? = nil) {
        let i = min(anchor, head)
        let j = max(anchor, head)
        let affinity: Affinity = anchor < head ? .downstream : .upstream

        self.init(range: i..<j, affinity: affinity, xOffset: xOffset, markedRange: markedRange)
    }

    private init(range: Range<Buffer.Index>, affinity: Affinity, xOffset: CGFloat?, markedRange: Range<Rope.Index>?) {
        self.range = range
        self.affinity = affinity
        self.xOffset = xOffset
        self.markedRange = markedRange
    }

    var isCaret: Bool {
        head == anchor
    }

    var isRange: Bool {
        !isCaret
    }

    var caret: Buffer.Index? {
        isCaret ? head : nil
    }

    var anchor: Buffer.Index {
        if affinity == .upstream {
            range.upperBound
        } else {
            range.lowerBound
        }
    }

    var head: Buffer.Index {
        if affinity == .upstream {
            range.lowerBound
        } else {
            range.upperBound
        }
    }

    var lowerBound: Buffer.Index {
        range.lowerBound
    }

    var upperBound: Buffer.Index {
        range.upperBound
    }

    var unmarked: Selection {
        Selection(range: range, affinity: affinity, xOffset: xOffset, markedRange: nil)
    }
}

// MARK: - Navigation
extension Selection {
    enum Movement {
        case left
        case right
        case leftWord
        case rightWord
        case up
        case down
        case beginningOfLine
        case endOfLine
        case beginningOfParagraph
        case endOfParagraph
        case beginningOfDocument
        case endOfDocument
    }

    init<D>(fromExisting selection: Selection, movement: Movement, extending: Bool, buffer: Buffer, layoutDataSource: D) where D: SelectionLayoutDataSource {
        if buffer.isEmpty {
            self.init(caretAt: buffer.startIndex, affinity: .upstream)
            return
        }

        let head: Buffer.Index
        var affinity: Affinity? = nil
        var xOffset: CGFloat? = nil

        switch movement {
        case .left:
            if selection.isCaret || extending {
                head = buffer.characters.index(before: selection.head, clampedTo: buffer.startIndex)
            } else {
                head = selection.lowerBound
            }
            affinity = head == buffer.endIndex ? .upstream : .downstream
        case .right:
            if selection.isCaret || extending {
                head = buffer.characters.index(after: selection.head, clampedTo: buffer.endIndex)
            } else {
                head = selection.upperBound
            }
            affinity = head == buffer.endIndex ? .upstream : .downstream
        case .up:
            (head, affinity, xOffset) = verticalDestination(selection: selection, movingUp: true, extending: extending, buffer: buffer, layoutDataSource: layoutDataSource)
        case .down:
            (head, affinity, xOffset) = verticalDestination(selection: selection, movingUp: false, extending: extending, buffer: buffer, layoutDataSource: layoutDataSource)
        case .leftWord:
            let wordBoundary = buffer.words.index(before: extending ? selection.head : selection.lowerBound, clampedTo: buffer.startIndex)
            if extending && selection.isRange && selection.affinity == .downstream {
                head = max(wordBoundary, selection.lowerBound)
            } else {
                head = wordBoundary
            }
            affinity = head == buffer.endIndex ? .upstream : .downstream
        case .rightWord:
            let wordBoundary = buffer.words.index(after: extending ? selection.head : selection.upperBound, clampedTo: buffer.endIndex)
            if extending && selection.isRange && selection.affinity == .upstream {
                head = min(selection.upperBound, wordBoundary)
            } else {
                head = wordBoundary
            }
            affinity = head == buffer.endIndex ? .upstream : .downstream
        case .beginningOfLine:
            guard let fragRange = layoutDataSource.lineFragmentRange(containing: selection.lowerBound, affinity: selection.isCaret ? selection.affinity : .downstream) else {
                assertionFailure("couldn't find fragRange")
                self = selection
                return
            }
            head = fragRange.lowerBound
            affinity = head == buffer.endIndex ? .upstream : .downstream
        case .endOfLine:
            guard let fragRange = layoutDataSource.lineFragmentRange(containing: selection.upperBound, affinity: selection.isCaret ? selection.affinity : .upstream) else {
                assertionFailure("couldn't find fragRange")
                self = selection
                return
            }

            let hardBreak = buffer[fragRange].characters.last == "\n"
            head = hardBreak ? buffer.index(before: fragRange.upperBound) : fragRange.upperBound
            affinity = hardBreak ? .downstream : .upstream
        case .beginningOfParagraph:
            head = buffer.lines.index(roundingDown: selection.lowerBound)
            affinity = head == buffer.endIndex ? .upstream : .downstream
        case .endOfParagraph:
            // end of document is end of last paragraph. This is
            // necessary so that we can distingush this case from
            // moving to the end of the second to last paragraph
            // when the last paragraph is an empty last line.
            if selection.upperBound == buffer.endIndex {
                head = buffer.endIndex
            } else {
                let i = buffer.lines.index(after: selection.upperBound, clampedTo: buffer.endIndex)
                if i == buffer.endIndex && buffer.characters.last != "\n" {
                    head = i
                } else {
                    head = buffer.index(before: i)
                }
            }
            affinity = head == buffer.endIndex ? .upstream : .downstream
        case .beginningOfDocument:
            head = buffer.startIndex
            affinity = buffer.isEmpty ? .upstream : .downstream
        case .endOfDocument:
            head = buffer.endIndex
            affinity = .upstream
        }

        if extending && (movement == .beginningOfLine || movement == .beginningOfParagraph || movement == .beginningOfDocument) {
            self.init(anchor: head, head: selection.upperBound)
        } else if extending && (movement == .endOfLine || movement == .endOfParagraph || movement == .endOfDocument) {
            self.init(anchor: head, head: selection.lowerBound)
        } else if extending && head != selection.anchor {
            self.init(anchor: selection.anchor, head: head, xOffset: xOffset)
        } else {
            // we're not extending, or we're extending and the destination is a caret (i.e. head == anchor)
            if let affinity {
                self.init(caretAt: head, affinity: affinity, xOffset: xOffset)
            } else {
                assertionFailure("missing affinity")
                self = selection
            }
        }
    }
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
func verticalDestination<D>(selection: Selection, movingUp: Bool, extending: Bool, buffer: Buffer, layoutDataSource: D) -> (Buffer.Index, Selection.Affinity, xOffset: CGFloat?) where D: SelectionLayoutDataSource {
    let i = selection.isRange && extending ? selection.head : selection.lowerBound
    let affinity: Selection.Affinity
    if i == buffer.endIndex {
        affinity = .upstream
    } else if selection.isCaret {
        affinity = selection.affinity
    } else if movingUp {
        affinity = .downstream
    } else {
        affinity = .upstream
    }

    // Moving up when we're already at the front or moving down when we're already
    // at the end is a no-op.
    if movingUp && selection.lowerBound == buffer.startIndex {
        return (selection.lowerBound, selection.affinity, selection.xOffset)
    }
    if !movingUp && selection.upperBound == buffer.endIndex {
        return (selection.upperBound, selection.affinity, selection.xOffset)
    }

    guard let fragRange = layoutDataSource.lineFragmentRange(containing: i, affinity: affinity) else {
        assertionFailure("couldn't find fragRange")
        return (selection.lowerBound, selection.affinity, selection.xOffset)
    }

    // Moving up when we're in the first frag, moves left to the beginning. Moving
    // down when we're in the last frag moves right to the end.
    //
    // When we're moving (not extending), because we're going horizontally, xOffset
    // gets cleared.
    if movingUp && fragRange.lowerBound == buffer.startIndex {
        let xOffset = extending ? selection.xOffset : nil
        return (buffer.startIndex, buffer.isEmpty ? .upstream : .downstream, xOffset)
    }
    if !movingUp && fragRange.upperBound == buffer.endIndex {
        let xOffset = extending ? selection.xOffset : nil
        return (buffer.endIndex, .upstream, xOffset)
    }

    let xOffset = selection.xOffset ?? layoutDataSource.point(forCharacterAt: i, affinity: affinity).x

    var target = movingUp ? fragRange.lowerBound : fragRange.upperBound

    // If we're at the beginning of a Line, we need to target the previous line.
    if movingUp && target > buffer.startIndex && buffer[buffer.index(before: target)] == "\n" {
        target = buffer.index(before: target)
    }
    let targetAffinity: Selection.Affinity = movingUp ? .upstream : .downstream
    
    guard let targetFragRange = layoutDataSource.lineFragmentRange(containing: target, affinity: targetAffinity) else {
        assertionFailure("couldn't find target fragRange")
        return (selection.lowerBound, selection.affinity, selection.xOffset)
    }

    guard let head = layoutDataSource.index(forHorizontalOffset: xOffset, inLineFragmentContaining: target, affinity: targetAffinity) else {
        assertionFailure("couldn't find head")
        return (selection.lowerBound, selection.affinity, selection.xOffset)
    }

    let newAffinity: Selection.Affinity = head == targetFragRange.upperBound ? .upstream : .downstream
    return (head, newAffinity, xOffset)
}
