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

extension InitializableFromSelectionAffinity {
    // fileprivate so there's no ambiguity in SelectionNavigatorTests when
    // we import StandardKeyBindingResponder as @testable.
    fileprivate static var upstream: Self { Self(.upstream) }
    fileprivate static var downstream: Self { Self(.downstream) }
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

    var anchor: Index { get }
    var head: Index { get }
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

    var isCaret: Bool {
        range.isEmpty
    }

    var isRange: Bool {
        !isCaret
    }
}

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
            return Selection(caretAt: dataSource.startIndex, affinity: Selection.Affinity(.upstream), xOffset: nil)
        }

        let newHead: Selection.Index
        var newAffinity: Selection.Affinity? = nil
        var xOffset: CGFloat? = nil

        switch movement {
        case .left:
            if selection.isCaret || extending {
                newHead = dataSource.index(beforeCharacter: selection.head, clampedTo: dataSource.startIndex)
            } else {
                newHead = selection.lowerBound
            }
            newAffinity = newHead == dataSource.endIndex ? .upstream : .downstream
        case .right:
            if selection.isCaret || extending {
                newHead = dataSource.index(afterCharacter: selection.head, clampedTo: dataSource.endIndex)
            } else {
                newHead = selection.upperBound
            }
            newAffinity = newHead == dataSource.endIndex ? .upstream : .downstream
        case .up:
            (newHead, newAffinity, xOffset) = verticalDestination(movingUp: true, extending: extending, dataSource: dataSource)
        case .down:
            (newHead, newAffinity, xOffset) = verticalDestination(movingUp: false, extending: extending, dataSource: dataSource)
        case .leftWord:
            let wordBoundary = dataSource.index(beforeWord: extending ? selection.head : selection.lowerBound, clampedTo: dataSource.startIndex)
            if extending && selection.isRange && selection.affinity == .downstream {
                newHead = max(wordBoundary, selection.lowerBound)
            } else {
                newHead = wordBoundary
            }
            newAffinity = newHead == dataSource.endIndex ? .upstream : .downstream
        case .rightWord:
            let wordBoundary = dataSource.index(afterWord: extending ? selection.head : selection.upperBound, clampedTo: dataSource.endIndex)
            if extending && selection.isRange && selection.affinity == .upstream {
                newHead = min(selection.range.upperBound, wordBoundary)
            } else {
                newHead = wordBoundary
            }
            newAffinity = newHead == dataSource.endIndex ? .upstream : .downstream
        case .beginningOfLine:
            guard let fragRange = dataSource.lineFragmentRange(containing: selection.lowerBound, affinity: selection.isCaret ? selection.affinity : .downstream) else {
                assertionFailure("couldn't find fragRange")
                return selection
            }
            newHead = fragRange.lowerBound
            newAffinity = newHead == dataSource.endIndex ? .upstream : .downstream
        case .endOfLine:
            guard let fragRange = dataSource.lineFragmentRange(containing: selection.upperBound, affinity: selection.isCaret ? selection.affinity : .upstream) else {
                assertionFailure("couldn't find fragRange")
                return selection
            }

            let hardBreak = dataSource.lastCharacter(inRange: fragRange) == "\n"
            newHead = hardBreak ? dataSource.index(beforeCharacter: fragRange.upperBound) : fragRange.upperBound
            newAffinity = hardBreak ? .downstream : .upstream
        case .beginningOfParagraph:
            newHead = dataSource.index(roundingDownToLine: selection.lowerBound)
            newAffinity = newHead == dataSource.endIndex ? .upstream : .downstream
        case .endOfParagraph:
            // end of document is end of last paragraph. This is
            // necessary so that we can distingush this case from
            // moving to the end of the second to last paragraph
            // when the last paragraph is an empty last line.
            if selection.upperBound == dataSource.endIndex {
                newHead = dataSource.endIndex
            } else {
                let i = dataSource.index(afterLine: selection.upperBound, clampedTo: dataSource.endIndex)
                if i == dataSource.endIndex && dataSource.lastCharacter(inRange: dataSource.documentRange) != "\n" {
                    newHead = i
                } else {
                    newHead = dataSource.index(beforeCharacter: i)
                }
            }
            newAffinity = newHead == dataSource.endIndex ? .upstream : .downstream
        case .beginningOfDocument:
            newHead = dataSource.startIndex
            newAffinity = dataSource.isEmpty ? .upstream : .downstream
        case .endOfDocument:
            newHead = dataSource.endIndex
            newAffinity = .upstream
        }

        if extending && (movement == .beginningOfLine || movement == .beginningOfParagraph || movement == .beginningOfDocument) {
            // Swap anchor and head so that if the next movement is endOf*, we end
            // up selecting the entire line, paragraph, or document.
            return Selection(anchor: newHead, head: selection.anchor, xOffset: nil)
        } else if extending && (movement == .endOfLine || movement == .endOfParagraph || movement == .endOfDocument) {
            // ditto
            return Selection(anchor: newHead, head: selection.lowerBound, xOffset: nil)
        } else if extending && newHead != selection.anchor {
            return Selection(anchor: selection.anchor, head: newHead, xOffset: xOffset)
        } else {
            // we're not extending, or we're extending and the destination is a caret (i.e. head == anchor)
            if let newAffinity {
                return Selection(caretAt: newHead, affinity: newAffinity, xOffset: xOffset)
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
    func verticalDestination(movingUp: Bool, extending: Bool, dataSource: DataSource) -> (Selection.Index, Selection.Affinity, xOffset: CGFloat?) {
        // Moving up when we're already at the front or moving down when we're already
        // isn't quite a no-op – if we're starting at a range, we'll end up with a
        // caret – but it's close.
        if movingUp && selection.lowerBound == dataSource.startIndex {
            return (selection.lowerBound, selection.affinity, selection.xOffset)
        }
        if !movingUp && selection.upperBound == dataSource.endIndex {
            // TODO: This might be wrong! If we're moving from a downstream range to the end of the doc would cause affinity to be downstream, which is an error.
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
        if movingUp && target > dataSource.startIndex && dataSource[dataSource.index(beforeCharacter: target)] == "\n" {
            target = dataSource.index(beforeCharacter: target)
        }
        let targetAffinity: SelectionAffinity = movingUp ? .upstream : .downstream

        guard let targetFragRange = dataSource.lineFragmentRange(containing: target, affinity: Selection.Affinity(targetAffinity)) else {
            assertionFailure("couldn't find target fragRange")
            return (selection.lowerBound, affinity, xOffset)
        }

        guard let head = dataSource.index(forHorizontalOffset: xOffset, inLineFragmentContaining: target, affinity: Selection.Affinity(targetAffinity)) else {
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

