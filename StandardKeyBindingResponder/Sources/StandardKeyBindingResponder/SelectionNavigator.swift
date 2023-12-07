//
//  SelectionNavigator.swift
//  StandardKeyBindingResponder
//
//  Created by David Albert on 11/2/23.
//

import Foundation

public enum Edge {
    case leading
    case trailing
}

public enum Affinity {
    case upstream
    case downstream
}

public protocol InitializableFromAffinity {
    init(_ affinity: Affinity)
}

// fileprivate so there's no ambiguity in SelectionNavigatorTests when
// we import StandardKeyBindingResponder as @testable.
fileprivate extension InitializableFromAffinity {
    static var upstream: Self { Self(.upstream) }
    static var downstream: Self { Self(.downstream) }
}

public enum Granularity: Equatable {
    case character
    case word
    case line
    case paragraph
}

public protocol InitializableFromGranularity {
    init(_ granularity: Granularity)
}

fileprivate extension InitializableFromGranularity {
    static var character: Self { Self(.character) }
    static var word: Self { Self(.word) }
    static var line: Self { Self(.line) }
    static var paragraph: Self { Self(.paragraph) }
}

extension Granularity {
    init<G>(_ granularity: G) where G: InitializableFromGranularity & Equatable {
        switch granularity {
        case .word: self = .word
        case .line: self = .line
        case .paragraph: self = .paragraph
        default: self = .character
        }
    }
}

public enum Movement: Equatable {
    case left
    case right
    case wordLeft
    case wordRight
    case up
    case down
    case beginningOfLine
    case endOfLine

    // paragraphBackward and paragraphForward are only used while extending. This is because
    // NSStandardKeyBindingResponding only has moveParagraphForwardAndModifySelection(_:)
    // and moveParagraphBackwardAndModifySelection(_:). No non-modifying variants.
    //
    // Behavior:
    // - Move Beginning/End: repeated movements in the same direction will move by an additional
    //   paragraph each time.
    // - Extend Beginning/End: repeated movements in the same direction are no-ops. Selection remains
    //   clamped inside the same paragraph.
    // - Extend Backward/Forward: repeated movements in the same direction will extend by additional
    //   paragraphs each time.
    case beginningOfParagraph
    case endOfParagraph
    case paragraphBackward
    case paragraphForward

    case beginningOfDocument
    case endOfDocument
}

public protocol NavigableSelection {
    associatedtype Index: Comparable
    associatedtype Affinity: InitializableFromAffinity & Equatable
    associatedtype Granularity: InitializableFromGranularity & Equatable

    init(caretAt index: Index, affinity: Affinity, granularity: Granularity, xOffset: CGFloat?)

    // xOffset will be non-nil when we extend a selection so that if
    // we extend the selection vertically up to startIndex and then
    // move down, or extend the selection vertically down to endIndex
    // and then move up, the caret will jump horizontally back to the
    // xOffset that was set following the first vertical move. This is
    // what Xcode does. I think it's of doubious value, and confusing,
    // so I might remove it.
    init(anchor: Index, head: Index, granularity: Granularity, xOffset: CGFloat?)

    var range: Range<Index> { get }
    var affinity: Affinity { get }
    var granularity: Granularity { get }
    var xOffset: CGFloat? { get }
}

extension NavigableSelection {
    var lowerBound: Index {
        range.lowerBound
    }

    var upperBound: Index {
        range.upperBound
    }

    var anchor: Index {
        if affinity == .upstream {
            range.upperBound
        } else {
            range.lowerBound
        }
    }

    var head: Index {
        if affinity == .upstream {
            range.lowerBound
        } else {
            range.upperBound
        }
    }

    var caretIndex: Index? {
        isCaret ? range.lowerBound : nil
    }

    var isCaret: Bool {
        range.isEmpty
    }

    var isRange: Bool {
        !isCaret
    }
}


public struct SelectionNavigator<Selection, DataSource> where Selection: NavigableSelection, DataSource: SelectionNavigationDataSource, Selection.Index == DataSource.Index {
    public let selection: Selection

    public init(_ selection: Selection) {
        self.selection = selection
    }
}

// MARK: - Keyboard navigation

extension SelectionNavigator {
    public func selection(moving movement: Movement, dataSource: DataSource) -> Selection {
        makeSelection(movement: movement, extending: false, dataSource: dataSource)
    }

    public func selection(extending movement: Movement, dataSource: DataSource) -> Selection {
        makeSelection(movement: movement, extending: true, dataSource: dataSource)
    }

    func makeSelection(movement: Movement, extending: Bool, dataSource: DataSource) -> Selection {
        if (movement == .paragraphBackward || movement == .paragraphForward) && !extending {
            preconditionFailure(String(describing: movement) + " can only be used when extending")
        }

        if dataSource.isEmpty {
            return Selection(caretAt: dataSource.startIndex, affinity: .upstream, granularity: .character, xOffset: nil)
        }

        // after this point, dataSource can't be empty, which means that moving to startIndex
        // can never yield an upstream affinity.

        let head: Selection.Index
        let affinity: Selection.Affinity
        var xOffset: CGFloat? = nil

        switch movement {
        case .left:
            if selection.isCaret || extending {
                head = selection.head == dataSource.startIndex ? selection.head : dataSource.index(before: selection.head)
            } else {
                head = selection.lowerBound
            }
            affinity = .downstream
        case .right:
            if selection.isCaret || extending {
                head = selection.head == dataSource.endIndex ? selection.head : dataSource.index(after: selection.head)
                affinity = head == dataSource.endIndex ? .upstream : .downstream
            } else {
                // moving right from a range
                head = selection.upperBound

                // if a selection ends at the end of a line fragment, and we move right
                // we want the caret to appear where the end of the selection was.
                let fragRange = dataSource.range(for: .line, enclosing: head)
                if fragRange.lowerBound == head {
                    affinity = .upstream
                } else {
                    affinity = head == dataSource.endIndex ? .upstream : .downstream
                }
            }
        case .up:
            (head, affinity, xOffset) = verticalDestination(movingUp: true, extending: extending, dataSource: dataSource)
        case .down:
            (head, affinity, xOffset) = verticalDestination(movingUp: false, extending: extending, dataSource: dataSource)
        case .wordLeft:
            let start = extending ? selection.head : selection.lowerBound
            let wordStart = dataSource.index(beginningOfWordBefore: start) ?? dataSource.startIndex
            let shrinking = extending && selection.isRange && selection.affinity == .downstream

            // if we're shrinking the selection, don't move past the anchor
            head = shrinking ? max(wordStart, selection.anchor) : wordStart
            affinity = .downstream
        case .wordRight:
            let start = extending ? selection.head : selection.upperBound
            let wordEnd = dataSource.index(endOfWordAfter: start) ?? dataSource.endIndex
            let shrinking = extending && selection.isRange && selection.affinity == .upstream

            // if we're shrinking the selection, don't move past the anchor
            head = shrinking ? min(selection.anchor, wordEnd) : wordEnd
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .beginningOfLine:
            let start = selection.lowerBound
            let fragRange = dataSource.range(for: .line, enclosing: start)

            if fragRange.isEmpty {
                // Empty last line. Includes empty document.
                head = start
            } else if start == fragRange.lowerBound && selection.isCaret && selection.affinity == .upstream {
                // we're actually on the previous frag
                let prevFrag = dataSource.range(for: .line, enclosing: dataSource.index(before: start))
                head = prevFrag.lowerBound
            } else {
                head = fragRange.lowerBound
            }
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .endOfLine:
            let start = selection.upperBound
            let fragRange = dataSource.range(for: .line, enclosing: start)

            if fragRange.isEmpty {
                // Empty last line. Includes empty document.
                head = start
                affinity = .upstream
            } else if start == fragRange.lowerBound && (selection.isRange || selection.affinity == .upstream) {
                // we're actually on the previous frag
                head = fragRange.lowerBound
                affinity = .upstream
            } else {
                let endsWithNewline = dataSource.lastCharacter(inRange: fragRange) == "\n"
                head = endsWithNewline ? dataSource.index(before: fragRange.upperBound) : fragRange.upperBound
                affinity = endsWithNewline ? .downstream : .upstream
            }
        // Multiple presses of Control-Shift-A (moveToBeginningOfParagraphAndModifySelection:) won't go
        // past the start of the paragraph, but multiple Option-Ups (moveToBeginningOfParagraph:) will.
        //
        // So, how can we have the same logic for .beginningOfParagraph whether or not extending == true?
        //
        // The answer is that the system actually maps Option-Up to the sequence [moveBackward:, moveToBeginningOfParagraph:].
        //
        // Ditto for Control-Shift-E and Option-Down.
        case .beginningOfParagraph:
            head = dataSource.range(for: .paragraph, enclosing: selection.lowerBound).lowerBound
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .endOfParagraph:
            let range = dataSource.range(for: .paragraph, enclosing: selection.upperBound)
            if dataSource.lastCharacter(inRange: range) == "\n" {
                head = dataSource.index(before: range.upperBound)
            } else {
                head = range.upperBound
            }
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .paragraphBackward:
            if selection.lowerBound == dataSource.startIndex {
                return selection
            }

            // lowerBound > startIndex, and upperBound >= lowerBound, therefore upperBound > startIndex.
            let r = dataSource.range(for: .paragraph, enclosing: dataSource.index(before: selection.upperBound))

            if selection.isCaret {
                return Selection(anchor: selection.upperBound, head: r.lowerBound, granularity: .character, xOffset: nil)
            }

            let sameParagraph = r.contains(selection.lowerBound)

            if sameParagraph && selection.lowerBound > r.lowerBound {
                // lowerBound and upperBound are in the same paragraph, and
                // we're not yet at the start of the paragraph.
                return Selection(anchor: selection.upperBound, head: r.lowerBound, granularity: .character, xOffset: nil)
            } else {
                let head = dataSource.index(ofParagraphBoundaryBefore: selection.head)
                return Selection(anchor: selection.anchor, head: head, granularity: .character, xOffset: nil)
            }
        case .paragraphForward:
            if selection.head == dataSource.endIndex {
                return selection
            }

            if selection.isCaret {
                let target = dataSource.index(before: selection.head)
                let head = dataSource.endOfParagraph(containing: target)
                return Selection(anchor: selection.lowerBound, head: head, granularity: .character, xOffset: nil)
            }

            assert(selection.lowerBound < selection.upperBound)
            let r = dataSource.range(for: .paragraph, enclosing: dataSource.index(before: selection.upperBound))
            let sameParagraph = r.contains(selection.lowerBound) || dataSource.distance(from: selection.lowerBound, to: r.lowerBound) == 1

            if sameParagraph && dataSource.distance(from: selection.upperBound, to: r.upperBound) > 2 {
                // lowerBound and upperBound are in the same paragraph, or lowerBound is at the
                // newline before the start of r2's paragraph.
                return Selection(anchor: selection.lowerBound, head: dataSource.index(before: r.upperBound), granularity: .character, xOffset: nil)
            } else {
                let start: Selection.Index
                if selection.head < dataSource.endIndex && dataSource[selection.head] == "\n" {
                    start = dataSource.index(after: selection.head)
                } else {
                    start = selection.head
                }
                let head = dataSource.endOfParagraph(containing: start)
                return Selection(anchor: selection.anchor, head: head, granularity: .character, xOffset: nil)
            }
        case .beginningOfDocument:
            head = dataSource.startIndex
            affinity = .downstream
        case .endOfDocument:
            head = dataSource.endIndex
            affinity = .upstream
        }

        // Granularity is always character because when selecting to the beginning or end of a
        // word, line, or paragraph, we may not have selected the entire word or paragraph.

        if extending && head != selection.upperBound && (movement == .beginningOfLine || movement == .beginningOfParagraph || movement == .beginningOfDocument) {
            // Swap anchor and head so that if the next movement is endOf*, we end
            // up selecting the entire line, paragraph, or document.
            return Selection(anchor: head, head: selection.upperBound, granularity: .character, xOffset: nil)
        } else if extending && head != selection.lowerBound && (movement == .endOfLine || movement == .endOfParagraph || movement == .endOfDocument) {
            // ditto
            return Selection(anchor: head, head: selection.lowerBound, granularity: .character, xOffset: nil)
        } else if extending && head != selection.anchor {
            return Selection(anchor: selection.anchor, head: head, granularity: .character, xOffset: xOffset)
        } else {
            // we're not extending, or we're extending and the destination is a caret (i.e. head == anchor)
            return Selection(caretAt: head, affinity: affinity, granularity: .character, xOffset: xOffset)
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
    // always corresponds to lowerBound.
    //
    // This is only called with a non-empty data source.
    func verticalDestination(movingUp: Bool, extending: Bool, dataSource: DataSource) -> (Selection.Index, Selection.Affinity, xOffset: CGFloat?) {
        assert(!dataSource.isEmpty)

        // If we're already at the start or end of the document, the destination
        // is the start or the end of the document.
        if movingUp && selection.lowerBound == dataSource.startIndex {
            return (selection.lowerBound, .downstream, selection.xOffset)
        }
        if !movingUp && selection.upperBound == dataSource.endIndex {
            return (selection.upperBound, .upstream, selection.xOffset)
        }

        let start: Selection.Index
        let horizAnchor: Selection.Index
        if selection.isRange && extending {
            start = selection.head
            horizAnchor = start
        } else if selection.isRange {
            start = movingUp ? selection.lowerBound : selection.upperBound
            horizAnchor = selection.lowerBound
        } else {
            start = selection.lowerBound
            horizAnchor = start
        }

        var fragRange = dataSource.range(for: .line, enclosing: start)
        if selection.isCaret && !fragRange.isEmpty && fragRange.lowerBound == start && selection.affinity == .upstream {
            assert(start != dataSource.startIndex)
            // we're actually in the previous frag
            fragRange = dataSource.range(for: .line, enclosing: dataSource.index(before: start))
        }

        let endsInNewline = dataSource.lastCharacter(inRange: fragRange) == "\n"
        let visualFragEnd = endsInNewline ? dataSource.index(before: fragRange.upperBound) : fragRange.upperBound

        // Moving up when we're in the first frag, moves left to the beginning. Moving
        // down when we're in the last frag moves right to the end.
        //
        // When we're moving (not extending), because we're going horizontally, xOffset
        // gets cleared.
        if movingUp && fragRange.lowerBound == dataSource.startIndex {
            let xOffset = extending ? selection.xOffset : nil
            return (dataSource.startIndex, .downstream, xOffset)
        }
        if !movingUp && visualFragEnd == dataSource.endIndex {
            let xOffset = extending ? selection.xOffset : nil
            return (dataSource.endIndex, .upstream, xOffset)
        }

        var horizAnchorFrag = fragRange
        if !fragRange.contains(horizAnchor) && fragRange.upperBound != horizAnchor {
            // we need the frag that contains horizAnchor
            horizAnchorFrag = dataSource.range(for: .line, enclosing: horizAnchor)
        }

        let xOffset = selection.xOffset ?? dataSource.caretOffset(forCharacterAt: horizAnchor, inLineFragmentWithRange: horizAnchorFrag)

        let target = movingUp ? dataSource.index(before: fragRange.lowerBound) : fragRange.upperBound
        let targetFragRange = dataSource.range(for: .line, enclosing: target)
        let (head, _) = dataSource.index(forCaretOffset: xOffset, inLineFragmentWithRange: targetFragRange)

        return (head, head == targetFragRange.upperBound ? .upstream : .downstream, xOffset)
    }
}

// MARK: - Mouse navigation

extension SelectionNavigator {
    public static func selection(interactingAt point: CGPoint, dataSource: DataSource) -> Selection {
        let fragRange = dataSource.lineFragmentRange(for: point)

        let index: Selection.Index
        let affinity: Selection.Affinity
        if let fragRange {
            (index, _) = dataSource.index(forCaretOffset: point.x, inLineFragmentWithRange: fragRange)
            affinity = index == fragRange.upperBound ? .upstream : .downstream
        } else {
            index = point.y < 0 ? dataSource.startIndex : dataSource.endIndex
            affinity = index == dataSource.endIndex ? .upstream : .downstream
        }

        return Selection(caretAt: index, affinity: affinity, granularity: .character, xOffset: nil)
    }

    public func selection(for granularity: Granularity, enclosing point: CGPoint, dataSource: DataSource) -> Selection {
        let fragRange: Range<Selection.Index>
        if let r = dataSource.lineFragmentRange(for: point) {
            fragRange = r
        } else if point.y < 0 {
            fragRange = dataSource.lineFragmentRange(containing: dataSource.startIndex)
        } else {
            fragRange = dataSource.lineFragmentRange(containing: dataSource.endIndex)
        }

        if fragRange.isEmpty {
            // empty last line (includes empty document)
            return Selection(caretAt: fragRange.lowerBound, affinity: .upstream, granularity: Selection.Granularity(granularity), xOffset: nil)
        }

        var (i, offset) = dataSource.index(forCaretOffset: point.x, inLineFragmentWithRange: fragRange)

        // index(forCaretOffset:inLineFragmentWithRange:) rounds to the closest caret offset. This means
        // for the string "a" with a character width of 8, anything in -inf..<4 will return index 0,
        // and 4...inf will return index 1.
        //
        // This behavior is good when clicking to create a caret – it places the caret at the closest
        // glyph boundary – but it's not what we want when double clicking to expand to a selection
        // to word granularity. For the string "   foo" if you double click directly on f's caret offset
        // we want to select "foo", but if you double click one point to the left, we want to select "   ".
        if point.x < offset && point.x >= 0 && i > dataSource.startIndex {
            i = dataSource.index(before: i)
        }

        var range = dataSource.range(for: granularity, enclosing: i == fragRange.upperBound ? dataSource.index(before: i) : i)
        // if fragRange isn't empty, range shouldn't be either
        assert(!range.isEmpty)

        // In general, if our selection starts at "\n", we want to expand to the previous
        // range, rather than expanding to cover the "\n". The only exception is when
        // the entire paragraph consists of "\n" – i.e. double clicking on an empty
        // line – we should select the newline.
        if granularity == .character || granularity == .word {
            let paragraph = dataSource.range(for: .paragraph, enclosing: selection.lowerBound)
            if dataSource[paragraph.lowerBound] != "\n" && dataSource[range.lowerBound] == "\n" {
                assert(dataSource.distance(from: paragraph.lowerBound, to: paragraph.upperBound) > 1)
                range = dataSource.range(for: granularity, enclosing: dataSource.index(before: selection.lowerBound))
            }
        }

        return Selection(anchor: range.lowerBound, head: range.upperBound, granularity: Selection.Granularity(granularity), xOffset: nil)
    }

    public func selection(extendingTo point: CGPoint, dataSource: DataSource) -> Selection {
        let fragRange: Range<Selection.Index>
        if let r = dataSource.lineFragmentRange(for: point) {
            fragRange = r
        } else if point.y < 0 {
            fragRange = dataSource.lineFragmentRange(containing: dataSource.startIndex)
        } else {
            fragRange = dataSource.lineFragmentRange(containing: dataSource.endIndex)
        }

        let (i, _) = dataSource.index(forCaretOffset: point.x, inLineFragmentWithRange: fragRange)

        if selection.granularity == .character {
            if i == selection.anchor {
                let affinity: Selection.Affinity = i == fragRange.upperBound ? .upstream : .downstream
                return Selection(caretAt: i, affinity: affinity, granularity: .character, xOffset: nil)
            } else {
                return Selection(anchor: selection.anchor, head: i, granularity: .character, xOffset: nil)
            }
        }

        // If we're moving by a granularity larger than a character, and we're
        // not on the empty last line, we should never have a caret.
        assert(selection.isRange)

        let anchor: Selection.Index
        let head: Selection.Index

        let range = dataSource.range(for: Granularity(selection.granularity), enclosing: i)

        if selection.affinity == .downstream && i < selection.lowerBound {
            // switching from downstream to upstream
            let originalRange = dataSource.range(for: Granularity(selection.granularity), enclosing: selection.lowerBound)
            anchor = originalRange.upperBound
        } else if selection.affinity == .upstream && i >= selection.upperBound {
            // switching from upstream to downstream
            let originalRange = dataSource.range(for: Granularity(selection.granularity), enclosing: dataSource.index(before: selection.anchor))
            anchor = originalRange.lowerBound
        } else {
            anchor = selection.anchor
        }

        // Rules for extending selections of words, lines, or paragraphs:
        // 1. The initially selected granule always stays selected. I.e. no carets.
        // 2. A new granule is selected only when the cursor has moved passed the
        //    first character (downstream) or the last character (upstream).
        //    Note: Rule 2 does not apply to the initial granule.
        //
        // Concretely consider the string "foo   bar" and a selection of word granularity
        // covering "   " (anchor=3, head=6).
        //
        // Rule 1 says that "   " must always be selected.
        // Rule 2 implies that "bar" is not selected until mouse.x is halfway through "b". When
        // that happens, the mouse's index is 7 and the selection is (anchor=3, head=9).
        // Rule 1 implies that when moving to the left of "   ", the anchor must switch from 3 to
        // 6 so that "   " remains selected. This happens when mouse.x is half way through the
        // second "o" in "foo". At that point, the selection would be (anchor=6, head=0).
        //
        // When deciding whether to use range.upperBound for head:
        // * `i >= selection.anchor` makes sure we're going to the right.
        // * `range.lowerBound == selection.anchor` enforces rule 1 by forcing
        //   us to always select the initial granule.
        // * `i > range.lowerBound` enforces rule 2 by only selecting a subsequent
        //   granule if we're past the first character in the granule.
        if i >= anchor && (range.lowerBound == anchor || i > range.lowerBound) {
            head = range.upperBound
        } else {
            head = range.lowerBound
        }

        assert(head != anchor)
        return Selection(anchor: anchor, head: head, granularity: selection.granularity, xOffset: nil)
    }
}
