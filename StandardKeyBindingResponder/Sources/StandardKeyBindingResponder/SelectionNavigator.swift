//
//  SelectionNavigator.swift
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

public protocol InitializableFromSelectionAffinity {
    init(_ affinity: SelectionAffinity)
}

// fileprivate so there's no ambiguity in SelectionNavigatorTests when
// we import StandardKeyBindingResponder as @testable.
fileprivate extension InitializableFromSelectionAffinity {
    static var upstream: Self { Self(.upstream) }
    static var downstream: Self { Self(.downstream) }
}

public protocol NavigableSelection {
    associatedtype Index: Comparable
    associatedtype Affinity: InitializableFromSelectionAffinity & Equatable

    init(caretAt index: Index, affinity: Affinity, xOffset: CGFloat?)

    // You might think that a non-caret Selection doesn't need an xOffset. We still need
    // to maintained maintain it for a specific special case: If we're moving up from within
    // the first fragment to the beginning of the document or moving down from the within
    // the last fragment to the end of the document, we want to maintain our xOffset so that
    // when we move back in the opposite vertical direction, we move by one line fragment and
    // also jump horizontally to our xOffset
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

    var isCaret: Bool {
        range.isEmpty
    }

    var isRange: Bool {
        !isCaret
    }
}

// TODO: consider bringing this design more in line with NSTextSelectionNavigation
// but in a more Swifty way.
//
// Specifically:
// - lineFragmentRange(containing:affinity:), as well as the line and word index functions
//   can be replaced with range(for granularity:, enclosing index:).
// - index(forHorizontalOffset:inLineFragmentContaining) could be replaced with
//   a) enumerateCaretOffsetsInLineFragment(at:using:) for the case where we need to know
//      the horizontal offset.
//   b) lineFragmentRange(for point:, at index:) for handling mouse clicks when we need
//      the equivalent of indexAndAffinity(interactingAt:).
//
// To implement verticalDestination(movingUp:extending:dataSource:), do the following:
// - find the range of the current frag with range(for granularity:, enclosing index:) -- how to deal with affinity?
// - get the xOffset of the current point using enumerateCaretOffsetsInLineFragment(at:using:)
// - get targetFragRange using range(for:enclosing:)
// - get head using enumerateCaretOffsetsInLineFragment(at:using:)
//
// I'm not sure if this is a good idea. It seems like the interface might be harder to implement? I'm not sure.
public protocol SelectionNavigationDataSource {
    // MARK: Storage
    associatedtype Index: Comparable
    associatedtype Affinity: InitializableFromSelectionAffinity

    var documentRange: Range<Index> { get }

    func index(beforeCharacter i: Index) -> Index
    func index(afterCharacter i: Index) -> Index

    func index(roundingDownToLine i: Index) -> Index
    func index(afterLine i: Index) -> Index

    func index(beforeWord i: Index) -> Index
    func index(afterWord i: Index) -> Index

    subscript(index: Index) -> Character { get }

    // MARK: Layout

    // TODO: the layout methods can return nil if given incorrect arguments. But we don't
    // want to crash the editor just because we can't generate a selection, so we assertFailure
    // in Debug. That feels a bit gross. Is there a better way to do it? Maybe a
    // different interface?
    func lineFragmentRange(containing index: Index, affinity: Affinity) -> Range<Index>?

    // returns the index that's closest to xOffset (i.e. xOffset gets rounded to the nearest character)
    func index(forHorizontalOffset xOffset: CGFloat, inLineFragmentContaining index: Index, affinity: Affinity) -> Index?

    // point is in text container coordinates
    func point(forCharacterAt index: Index, affinity: Affinity) -> CGPoint
}


public struct SelectionNavigator<Selection, DataSource> where Selection: NavigableSelection, DataSource: SelectionNavigationDataSource, Selection.Index == DataSource.Index, Selection.Affinity == DataSource.Affinity {
    public let selection: Selection

    public init(selection: Selection) {
        self.selection = selection
    }

    public func move(_ movement: SelectionMovement, dataSource: DataSource) -> Selection {
        makeSelection(movement: movement, extending: false, dataSource: dataSource)
    }

    public func extend(_ movement: SelectionMovement, dataSource: DataSource) -> Selection {
        makeSelection(movement: movement, extending: true, dataSource: dataSource)
    }

    func makeSelection(movement: SelectionMovement, extending: Bool, dataSource: DataSource) -> Selection {
        if dataSource.isEmpty {
            return Selection(caretAt: dataSource.startIndex, affinity: .upstream, xOffset: nil)
        }

        // after this point, dataSource can't be empty, which means that moving to startIndex
        // can never yield an upstream affinity.

        let head: Selection.Index
        var affinity: Selection.Affinity? = nil
        var xOffset: CGFloat? = nil

        switch movement {
        case .left:
            if selection.isCaret || extending {
                head = dataSource.index(beforeCharacter: selection.head, clampedTo: dataSource.startIndex)
            } else {
                head = selection.lowerBound
            }
            // dataSource can't be empty, and we're moving left, so we're never at endIndex, so
            // affinity can't be .upstream.
            affinity = .downstream
        case .right:
            if selection.isCaret || extending {
                head = dataSource.index(afterCharacter: selection.head, clampedTo: dataSource.endIndex)
            } else {
                head = selection.upperBound
            }
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .up:
            (head, affinity, xOffset) = verticalDestination(movingUp: true, extending: extending, dataSource: dataSource)
        case .down:
            (head, affinity, xOffset) = verticalDestination(movingUp: false, extending: extending, dataSource: dataSource)
        case .leftWord:
            let wordBoundary = dataSource.index(beforeWord: extending ? selection.head : selection.lowerBound, clampedTo: dataSource.startIndex)
            if extending && selection.isRange && selection.affinity == .downstream {
                head = max(wordBoundary, selection.lowerBound)
            } else {
                head = wordBoundary
            }
            // dataSource can't be empty, so moving left can't cause an affinity of .upstream
            affinity = .downstream
        case .rightWord:
            let wordBoundary = dataSource.index(afterWord: extending ? selection.head : selection.upperBound, clampedTo: dataSource.endIndex)
            if extending && selection.isRange && selection.affinity == .upstream {
                head = min(selection.range.upperBound, wordBoundary)
            } else {
                head = wordBoundary
            }
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .beginningOfLine:
            guard let fragRange = dataSource.lineFragmentRange(containing: selection.lowerBound, affinity: selection.isCaret ? selection.affinity : .downstream) else {
                assertionFailure("couldn't find fragRange")
                return selection
            }
            head = fragRange.lowerBound
            // Even though we're moving left, if the line is the empty last line, we could be
            // at endIndex and need an upstream affinity.
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .endOfLine:
            guard let fragRange = dataSource.lineFragmentRange(containing: selection.upperBound, affinity: selection.isCaret ? selection.affinity : .upstream) else {
                assertionFailure("couldn't find fragRange")
                return selection
            }

            let hardBreak = dataSource.lastCharacter(inRange: fragRange) == "\n"
            head = hardBreak ? dataSource.index(beforeCharacter: fragRange.upperBound) : fragRange.upperBound
            affinity = hardBreak ? .downstream : .upstream
        case .beginningOfParagraph:
            head = dataSource.index(roundingDownToLine: selection.lowerBound)
            affinity = .downstream
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
            if let affinity {
                return Selection(caretAt: head, affinity: affinity, xOffset: xOffset)
            } else {
                assertionFailure("missing affinity")
                return selection
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
    // always corresponds to lowerBound.
    //
    // This is only called with a non-empty data source.
    func verticalDestination(movingUp: Bool, extending: Bool, dataSource: DataSource) -> (Selection.Index, Selection.Affinity, xOffset: CGFloat?) {
        assert(!dataSource.isEmpty)

        // Moving up when we're already at the front or moving down when we're already
        // isn't quite a no-op – if we're starting at a range, we'll end up with a
        // caret – but it's close.
        if movingUp && selection.lowerBound == dataSource.startIndex {
            return (selection.lowerBound, selection.affinity, selection.xOffset)
        }
        if !movingUp && selection.upperBound == dataSource.endIndex {
            return (selection.upperBound, selection.affinity, selection.xOffset)
        }

        let i = selection.isRange && extending ? selection.head : selection.lowerBound
        let affinity: Selection.Affinity
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
            return (selection.lowerBound, affinity, selection.xOffset)
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
        if movingUp && dataSource.index(roundingDownToLine: target) == target {
            target = dataSource.index(beforeCharacter: target)
        }
        let targetAffinity: Selection.Affinity = movingUp ? .upstream : .downstream

        guard let targetFragRange = dataSource.lineFragmentRange(containing: target, affinity: targetAffinity) else {
            assertionFailure("couldn't find target fragRange")
            return (selection.lowerBound, affinity, xOffset)
        }

        guard let head = dataSource.index(forHorizontalOffset: xOffset, inLineFragmentContaining: target, affinity: targetAffinity) else {
            assertionFailure("couldn't find head")
            return (selection.lowerBound, affinity, xOffset)
        }

        return (head, head == targetFragRange.upperBound ? .upstream : .downstream, xOffset)
    }
}

// MARK: Internal helpers
extension SelectionNavigationDataSource {
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
extension SelectionNavigationDataSource {
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

