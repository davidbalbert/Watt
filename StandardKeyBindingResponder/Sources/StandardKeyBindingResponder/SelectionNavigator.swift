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

public enum Granularity {
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

public enum Movement: Equatable {
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

public protocol NavigableSelection {
    associatedtype Index: Comparable
    associatedtype Affinity: InitializableFromAffinity & Equatable

    init(caretAt index: Index, affinity: Affinity, xOffset: CGFloat?)

    // xOffset will be non-nil when we extend a selection so that if
    // we extend the selection vertically up to startIndex and then
    // move down, or extend the selection vertically down to endIndex
    // and then move up, the caret will jump horizontally back to the
    // xOffset that was set following the first vertical move. This is
    // what Xcode does. I think it's of doubious value, and confusing,
    // so I might remove it.
    init(anchor: Index, head: Index, xOffset: CGFloat?)

    var range: Range<Index> { get }
    var affinity: Affinity { get }
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

    public init(selection: Selection) {
        self.selection = selection
    }
}

// MARK: - Keyboard navigation

extension SelectionNavigator {
    public func move(_ movement: Movement, dataSource: DataSource) -> Selection {
        makeSelection(movement: movement, extending: false, dataSource: dataSource)
    }

    public func extend(_ movement: Movement, dataSource: DataSource) -> Selection {
        makeSelection(movement: movement, extending: true, dataSource: dataSource)
    }

    func makeSelection(movement: Movement, extending: Bool, dataSource: DataSource) -> Selection {
        if dataSource.isEmpty {
            return Selection(caretAt: dataSource.startIndex, affinity: .upstream, xOffset: nil)
        }

        // after this point, dataSource can't be empty, which means that moving to startIndex
        // can never yield an upstream affinity.

        let head: Selection.Index
        var affinity: Selection.Affinity
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
        case .leftWord:
            let start = extending ? selection.head : selection.lowerBound
            let wordStart = dataSource.index(beginningOfWordBefore: start) ?? dataSource.startIndex
            let shrinking = extending && selection.isRange && selection.affinity == .downstream

            // if we're shrinking the selection, don't move past the anchor
            head = shrinking ? max(wordStart, selection.anchor) : wordStart
            affinity = .downstream
        case .rightWord:
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
        case .beginningOfParagraph:
            head = dataSource.range(for: .paragraph, enclosing: selection.lowerBound).lowerBound
            affinity = .downstream
        case .endOfParagraph:
            let range = dataSource.range(for: .paragraph, enclosing: selection.upperBound)
            if dataSource.lastCharacter(inRange: range) == "\n" {
                head = dataSource.index(before: range.upperBound)
            } else {
                head = range.upperBound
            }
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .beginningOfDocument:
            head = dataSource.startIndex
            affinity = .downstream
        case .endOfDocument:
            head = dataSource.endIndex
            affinity = .upstream
        }

        if extending && (movement == .beginningOfLine || movement == .beginningOfParagraph || movement == .beginningOfDocument) {
            assert(head != selection.upperBound)
            // Swap anchor and head so that if the next movement is endOf*, we end
            // up selecting the entire line, paragraph, or document.
            return Selection(anchor: head, head: selection.upperBound, xOffset: nil)
        } else if extending && (movement == .endOfLine || movement == .endOfParagraph || movement == .endOfDocument) {
            assert(head != selection.lowerBound)
            // ditto
            return Selection(anchor: head, head: selection.lowerBound, xOffset: nil)
        } else if extending && head != selection.anchor {
            return Selection(anchor: selection.anchor, head: head, xOffset: xOffset)
        } else {
            // we're not extending, or we're extending and the destination is a caret (i.e. head == anchor)
            return Selection(caretAt: head, affinity: affinity, xOffset: xOffset)
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
        let head = dataSource.index(forCaretOffset: xOffset, inLineFragmentWithRange: targetFragRange)

        return (head, head == targetFragRange.upperBound ? .upstream : .downstream, xOffset)
    }
}

// MARK: - Mouse navigation

public extension SelectionNavigator {
    static func selection(interactingAt point: CGPoint, dataSource: DataSource) -> Selection {
        let fragRange = dataSource.lineFragmentRange(for: point)

        let index: Selection.Index
        let affinity: Selection.Affinity
        if let fragRange {
            index = dataSource.index(forCaretOffset: point.x, inLineFragmentWithRange: fragRange)
            affinity = index == fragRange.upperBound ? .upstream : .downstream
        } else {
            index = point.y < 0 ? dataSource.startIndex : dataSource.endIndex
            affinity = index == dataSource.endIndex ? .upstream : .downstream
        }

        return Selection(caretAt: index, affinity: affinity, xOffset: nil)
    }

    func extendSelection(to granularity: Granularity, dataSource: DataSource) -> Selection {
        let range = dataSource.range(for: granularity, enclosing: selection.lowerBound)
        if range.isEmpty {
            let affinity: Selection.Affinity = range.lowerBound == dataSource.endIndex ? .upstream : .downstream
            return Selection(caretAt: range.lowerBound, affinity: affinity, xOffset: nil)
        }

        return Selection(anchor: range.lowerBound, head: range.upperBound, xOffset: nil)
    }

    func extendSelection(interactingAt point: CGPoint, dataSource: DataSource) -> Selection {
        let fragRange = dataSource.lineFragmentRange(for: point)

        let head: Selection.Index
        let affinity: Selection.Affinity
        if let fragRange {
            head = dataSource.index(forCaretOffset: point.x, inLineFragmentWithRange: fragRange)
            affinity = head == fragRange.upperBound ? .upstream : .downstream
        } else {
            head = point.y < 0 ? dataSource.startIndex : dataSource.endIndex
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        }

        if head == selection.anchor {
            return Selection(caretAt: head, affinity: affinity, xOffset: nil)
        } else {
            return Selection(anchor: selection.anchor, head: head, xOffset: nil)
        }
    }
}
