//
//  Selection.swift
//  StandardKeyBindingResponder
//
//  Created by David Albert on 11/2/23.
//

import Foundation

public enum SelectionAffinity {
    case upstream
    case downstream
}

public enum SelectionMovement: Equatable {
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

public struct Selection<Index>: Equatable where Index: Comparable {
    public let range: Range<Index>
    // For caret, determines which side of a line wrap the caret is on.
    // For range, determins which the end is head, and which end is the anchor.
    public let affinity: SelectionAffinity
    public let xOffset: CGFloat?

    public init(range: Range<Index>, affinity: SelectionAffinity, xOffset: CGFloat?) {
        self.range = range
        self.affinity = affinity
        self.xOffset = xOffset
    }

    public init(caretAt i: Index, affinity: SelectionAffinity, xOffset: CGFloat? = nil) {
        self.init(range: i..<i, affinity: affinity, xOffset: xOffset)
    }

    public init(anchor: Index, head: Index, xOffset: CGFloat? = nil) {
        let i = min(anchor, head)
        let j = max(anchor, head)
        let affinity: SelectionAffinity = anchor < head ? .downstream : .upstream

        self.init(range: i..<j, affinity: affinity, xOffset: xOffset)
    }

    var isCaret: Bool {
        head == anchor
    }

    var isRange: Bool {
        !isCaret
    }

    var caret: Index? {
        isCaret ? head : nil
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

    var lowerBound: Index {
        range.lowerBound
    }

    var upperBound: Index {
        range.upperBound
    }

}

// MARK: - Selection navigation
public protocol SelectionDataSource {
    // MARK: Storage
    associatedtype Index: Comparable

    var documentRange: Range<Index> { get }

    func index(beforeCharacter i: Index) -> Index
    func index(afterCharacter i: Index) -> Index

    func index(roundingDownToLine i: Index) -> Index
    func index(afterLine i: Index) -> Index

    func index(beforeWord i: Index) -> Index
    func index(afterWord i: Index) -> Index

    subscript(index: Index) -> Character { get }

    // MARK: Layout
    func lineFragmentRange(containing index: Index, affinity: SelectionAffinity) -> Range<Index>?

    // returns the index that's closest to xOffset (i.e. xOffset gets rounded to the nearest character)
    func index(forHorizontalOffset xOffset: CGFloat, inLineFragmentContaining index: Index, affinity: SelectionAffinity) -> Index?

    // point is in text container coordinates
    func point(forCharacterAt index: Index, affinity: SelectionAffinity) -> CGPoint
}

// MARK: Internal helpers
extension SelectionDataSource {
    var isEmpty: Bool {
        documentRange.isEmpty
    }

    var startIndex: Index {
        documentRange.lowerBound
    }

    var endIndex: Index {
        documentRange.upperBound
    }

    func index(beforeCharacter i: Index, clampedTo limit: Index) -> Index {
        if i <= limit {
            return limit
        }
        return index(beforeCharacter: i)
    }

    func index(afterCharacter i: Index, clampedTo limit: Index) -> Index {
        if i >= limit {
            return limit
        }
        return index(afterCharacter: i)
    }

    func index(beforeWord i: Index, clampedTo limit: Index) -> Index {
        if i <= limit {
            return limit
        }
        return index(beforeWord: i)
    }

    func index(afterWord i: Index, clampedTo limit: Index) -> Index {
        if i >= limit {
            return limit
        }
        return index(afterWord: i)
    }

    func index(afterLine i: Index, clampedTo limit: Index) -> Index {
        if i >= limit {
            return limit
        }
        return index(afterLine: i)
    }

    func isWordCharacter(_ c: Character) -> Bool {
        !c.isWhitespace && !c.isPunctuation
    }

    func lastCharacter(inRange range: Range<Index>) -> Character? {
        if range.isEmpty {
            return nil
        }

        return self[index(beforeCharacter: range.upperBound)]
    }
}

// MARK: Default implementations
extension SelectionDataSource {
    func index(roundingDownToLine i: Index) -> Index {
        var i = i
        while i > startIndex {
            let prev = index(beforeCharacter: i)
            if self[prev] == "\n" {
                break
            }
            i = prev
        }
        return i
    }

    func index(afterLine i: Index) -> Index {
        var i = i
        while i < endIndex {
            let prev = i
            i = index(afterCharacter: i)
            if self[prev] == "\n" {
                break
            }
        }
        return i
    }

    func index(beforeWord i: Index) -> Index {
        var i = i
        while i > startIndex && !isWordCharacter(self[index(beforeCharacter: i)]) {
            i = index(beforeCharacter: i)
        }
        while i > startIndex && isWordCharacter(self[index(beforeCharacter: i)]) {
            i = index(beforeCharacter: i)
        }
        return i
    }

    func index(afterWord i: Index) -> Index {
        var i = i
        while i < endIndex && !isWordCharacter(self[i]) {
            i = index(afterCharacter: i)
        }
        while i < endIndex && isWordCharacter(self[i]) {
            i = index(afterCharacter: i)
        }

        return i
    }
}

extension Selection {
    public init<DataSource>(fromExisting selection: Selection, movement: SelectionMovement, extending: Bool, dataSource: DataSource) where DataSource: SelectionDataSource, DataSource.Index == Index {
        if dataSource.isEmpty {
            self.init(caretAt: dataSource.startIndex, affinity: .upstream)
            return
        }

        let head: Index
        var affinity: SelectionAffinity? = nil
        var xOffset: CGFloat? = nil

        switch movement {
        case .left:
            if selection.isCaret || extending {
                head = dataSource.index(beforeCharacter: selection.head, clampedTo: dataSource.startIndex)
            } else {
                head = selection.lowerBound
            }
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .right:
            if selection.isCaret || extending {
                head = dataSource.index(afterCharacter: selection.head, clampedTo: dataSource.endIndex)
            } else {
                head = selection.upperBound
            }
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .up:
            (head, affinity, xOffset) = verticalDestination(selection: selection, movingUp: true, extending: extending, dataSource: dataSource)
        case .down:
            (head, affinity, xOffset) = verticalDestination(selection: selection, movingUp: false, extending: extending, dataSource: dataSource)
        case .leftWord:
            let wordBoundary = dataSource.index(beforeWord: extending ? selection.head : selection.lowerBound, clampedTo: dataSource.startIndex)
            if extending && selection.isRange && selection.affinity == .downstream {
                head = max(wordBoundary, selection.lowerBound)
            } else {
                head = wordBoundary
            }
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .rightWord:
            let wordBoundary = dataSource.index(afterWord: extending ? selection.head : selection.upperBound, clampedTo: dataSource.endIndex)
            if extending && selection.isRange && selection.affinity == .upstream {
                head = min(selection.upperBound, wordBoundary)
            } else {
                head = wordBoundary
            }
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .beginningOfLine:
            guard let fragRange = dataSource.lineFragmentRange(containing: selection.lowerBound, affinity: selection.isCaret ? selection.affinity : .downstream) else {
                assertionFailure("couldn't find fragRange")
                self = selection
                return
            }
            head = fragRange.lowerBound
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .endOfLine:
            guard let fragRange = dataSource.lineFragmentRange(containing: selection.upperBound, affinity: selection.isCaret ? selection.affinity : .upstream) else {
                assertionFailure("couldn't find fragRange")
                self = selection
                return
            }

            let hardBreak = dataSource.lastCharacter(inRange: fragRange) == "\n"
            head = hardBreak ? dataSource.index(beforeCharacter: fragRange.upperBound) : fragRange.upperBound
            affinity = hardBreak ? .downstream : .upstream
        case .beginningOfParagraph:
            head = dataSource.index(roundingDownToLine: selection.lowerBound)
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .endOfParagraph:
            // end of document is end of last paragraph. This is
            // necessary so that we can distingush this case from
            // moving to the end of the second to last paragraph
            // when the last paragraph is an empty last line.
            if selection.upperBound == dataSource.endIndex {
                head = dataSource.endIndex
            } else {
                let i = dataSource.index(afterLine: selection.upperBound, clampedTo: dataSource.endIndex)
                if i == dataSource.endIndex && dataSource.lastCharacter(inRange: dataSource.documentRange) != "\n" {
                    head = i
                } else {
                    head = dataSource.index(beforeCharacter: i)
                }
            }
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .beginningOfDocument:
            head = dataSource.startIndex
            affinity = dataSource.isEmpty ? .upstream : .downstream
        case .endOfDocument:
            head = dataSource.endIndex
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
func verticalDestination<Index, DataSource>(selection: Selection<Index>, movingUp: Bool, extending: Bool, dataSource: DataSource) -> (Index, SelectionAffinity, xOffset: CGFloat?) where DataSource: SelectionDataSource, Index == DataSource.Index {
    // Moving up when we're already at the front or moving down when we're already
    // at the end is a no-op.
    if movingUp && selection.lowerBound == dataSource.startIndex {
        return (selection.lowerBound, selection.affinity, selection.xOffset)
    }
    if !movingUp && selection.upperBound == dataSource.endIndex {
        return (selection.upperBound, selection.affinity, selection.xOffset)
    }

    let i = selection.isRange && extending ? selection.head : selection.lowerBound
    let affinity: SelectionAffinity
    if i == dataSource.endIndex {
        affinity = .upstream
    } else if selection.isCaret {
        affinity = selection.affinity
    } else if movingUp {
        affinity = .downstream
    } else {
        affinity = .upstream
    }

    guard let fragRange = dataSource.lineFragmentRange(containing: i, affinity: affinity) else {
        assertionFailure("couldn't find fragRange")
        return (selection.lowerBound, selection.affinity, selection.xOffset)
    }

    // Moving up when we're in the first frag, moves left to the beginning. Moving
    // down when we're in the last frag moves right to the end.
    //
    // When we're moving (not extending), because we're going horizontally, xOffset
    // gets cleared.
    if movingUp && fragRange.lowerBound == dataSource.startIndex {
        let xOffset = extending ? selection.xOffset : nil
        return (dataSource.startIndex, dataSource.isEmpty ? .upstream : .downstream, xOffset)
    }
    if !movingUp && fragRange.upperBound == dataSource.endIndex {
        let xOffset = extending ? selection.xOffset : nil
        return (dataSource.endIndex, .upstream, xOffset)
    }

    // This needs a type declaration or it will be inferred as a CGFloat?. I'm not sure why.
    let xOffset: CGFloat = selection.xOffset ?? dataSource.point(forCharacterAt: i, affinity: affinity).x

    var target = movingUp ? fragRange.lowerBound : fragRange.upperBound

    // If we're at the beginning of a Line, we need to target the previous line.
    if movingUp && target > dataSource.startIndex && dataSource[dataSource.index(beforeCharacter: target)] == "\n" {
        target = dataSource.index(beforeCharacter: target)
    }
    let targetSelectionAffinity: SelectionAffinity = movingUp ? .upstream : .downstream

    guard let targetFragRange = dataSource.lineFragmentRange(containing: target, affinity: targetSelectionAffinity) else {
        assertionFailure("couldn't find target fragRange")
        return (selection.lowerBound, selection.affinity, selection.xOffset)
    }

    guard let head = dataSource.index(forHorizontalOffset: xOffset, inLineFragmentContaining: target, affinity: targetSelectionAffinity) else {
        assertionFailure("couldn't find head")
        return (selection.lowerBound, selection.affinity, selection.xOffset)
    }

    let newSelectionAffinity: SelectionAffinity = head == targetFragRange.upperBound ? .upstream : .downstream
    return (head, newSelectionAffinity, xOffset)
}
