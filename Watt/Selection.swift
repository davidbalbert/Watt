//
//  Selection.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import Foundation

struct Selection {
    enum Affinity {
        case upstream
        case downstream
    }

    enum Granularity {
        case character
        case word
        case line        
    }

    let range: Range<Buffer.Index>
    let affinity: Affinity
    let xOffset: CGFloat?
    let markedRange: Range<Rope.Index>?

    init(caretAt index: Buffer.Index, affinity: Affinity, xOffset: CGFloat? = nil, markedRange: Range<Rope.Index>? = nil) {
        self.init(range: index..<index, affinity: affinity, xOffset: xOffset, markedRange: markedRange)
    }

    init(anchor: Buffer.Index, head: Buffer.Index, markedRange: Range<Rope.Index>? = nil) {
        let i = min(anchor, head)
        let j = max(anchor, head)
        let affinity: Affinity = anchor < head ? .downstream : .upstream

        self.init(range: i..<j, affinity: affinity, xOffset: nil, markedRange: markedRange)
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

    init(fromExisting selection: Selection, movement: Movement, extending: Bool, buffer: Buffer, layoutManager: LayoutManager) {
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
            affinity = .downstream
        case .right:
            if selection.isCaret || extending {
                head = buffer.characters.index(after: selection.head, clampedTo: buffer.endIndex)
            } else {
                head = selection.upperBound
            }
            affinity = .downstream
        case .leftWord:
            head = buffer.words.index(before: selection.head, clampedTo: buffer.startIndex)
            affinity = .downstream
        case .rightWord:
            head = buffer.words.index(after: selection.head, clampedTo: buffer.endIndex)
            affinity = .downstream
        case .up:
            (head, xOffset) = verticalDestination(selection: selection, movingUp: true, extending: extending, buffer: buffer, layoutManager: layoutManager)
            if !extending || head == selection.anchor {
                affinity = .upstream
            }
        case .down:
            (head, xOffset) = verticalDestination(selection: selection, movingUp: false, extending: extending, buffer: buffer, layoutManager: layoutManager)
            if !extending || head == selection.anchor {
                affinity = .downstream
            }
        case .beginningOfLine:
            let line = layoutManager.line(containing: selection.lowerBound)
            if let frag = line.fragment(containing: selection.lowerBound, affinity: selection.isCaret ? selection.affinity : .downstream) {
                head = frag.range.lowerBound
            } else {
                assertionFailure("couldn't find frag")
                head = selection.lowerBound
            }
            affinity = head == buffer.endIndex ? .upstream : .downstream
        case .endOfLine:
            let line = layoutManager.line(containing: selection.upperBound)
            guard let frag = line.fragment(containing: selection.upperBound, affinity: selection.isCaret ? selection.affinity : .upstream) else {
                assertionFailure("couldn't find frag")
                self = selection
                return
            }

            let hardBreak = buffer[frag.range].characters.last == "\n"
            head = hardBreak ? buffer.index(before: frag.range.upperBound) : frag.range.upperBound
            affinity = hardBreak ? .downstream : .upstream
        case .beginningOfParagraph:
            head = buffer.lines.index(roundingDown: selection.lowerBound)
            affinity = head == buffer.endIndex ? .upstream : .downstream
        case .endOfParagraph:
            // end of document is end of last paragraph. This is
            // necessary so that we can distingush this case from
            // moving to the end of the second paragraph when the
            // last paragraph is an empty last line.
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
            affinity = .upstream
        case .beginningOfDocument:
            self.init(caretAt: buffer.startIndex, affinity: .downstream)
            return
        case .endOfDocument:
            self.init(caretAt: buffer.endIndex, affinity: .upstream)
            return
        }

        if !extending || head == selection.anchor, let affinity {
            self.init(caretAt: head, affinity: affinity, xOffset: xOffset)
        } else if !extending || head == selection.anchor {
            assertionFailure("missing affinity")
            self = selection
        } else if movement == .beginningOfLine || movement == .beginningOfParagraph || movement == .beginningOfDocument{
            self.init(anchor: head, head: selection.upperBound)
        } else if movement == .endOfLine || movement == .endOfParagraph || movement == .endOfDocument {
            self.init(anchor: head, head: selection.lowerBound)
        } else {
            self.init(anchor: selection.anchor, head: head)
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
func verticalDestination(selection: Selection, movingUp: Bool, extending: Bool, buffer: Buffer, layoutManager: LayoutManager) -> (Buffer.Index, xOffset: CGFloat?) {
    let i = extending ? selection.lowerBound : selection.head

    let line = layoutManager.line(containing: i)
    guard let frag = line.fragment(containing: i, affinity: selection.isCaret ? selection.affinity : (movingUp ? .downstream : .upstream)) else {
        assertionFailure("couldn't find frag")
        return (selection.lowerBound, nil)
    }

    if movingUp {
        if frag.range.lowerBound == buffer.startIndex {
            return (buffer.startIndex, nil)
        }
    } else {
        if frag.range.upperBound == buffer.endIndex {
            return (buffer.endIndex, nil)
        }
    }

    let xOffset: CGFloat
    if let x = selection.xOffset {
        xOffset = x
    } else {
        xOffset = layoutManager.position(inFrag: frag, forCharacterAt: i, lineStart: line.range.lowerBound).x
    }

    let pointInFrag = CGPoint(
        x: xOffset,
        y: movingUp ? -0.0001 : frag.alignmentFrame.height
    )
    let pointInLine = layoutManager.convert(pointInFrag, from: frag)
    let point = layoutManager.convert(pointInLine, from: line)
    let head = layoutManager.location(interactingAt: point)

    return (head, xOffset)
}
