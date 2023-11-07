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

public enum SelectionGranularity {
    case character
    case word
    case line
    case paragraph
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

    // You might think that a non-caret Selection doesn't need an xOffset, but we still
    // need to maintain it for a specific special case: If we're moving up from within
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

    var documentRange: Range<Index> { get }

    func index(beforeCharacter i: Index) -> Index
    func index(afterCharacter i: Index) -> Index
    func distance(from start: Index, to end: Index) -> Int

    func index(beforeParagraph i: Index) -> Index
    func index(afterParagraph i: Index) -> Index

    subscript(index: Index) -> Character { get }

    // MARK: Layout

    func lineFragmentRange(containing index: Index) -> Range<Index>
    func enumerateCaretOffsetsInLineFragment(containing index: Index, using block: (_ offset: CGFloat, _ i: Index, _ leadingEdge: Bool) -> Bool)
    // If we do the above refactor and change this to range(for:enclosing:), we might
    // be able to get away with not passing in affinity and having that always return
    // a range.
//    func lineFragmentRange(containing index: Index, affinity: Affinity) -> Range<Index>?

    // returns the index that's closest to xOffset (i.e. xOffset gets rounded to the nearest character)
//    func index(forHorizontalOffset xOffset: CGFloat, inLineFragmentContaining index: Index, affinity: Affinity) -> Index?

    // point is in text container coordinates
//    func point(forCharacterAt index: Index, affinity: Affinity) -> CGPoint

    func isWordStart(_ i: Index) -> Bool
    func isWordEnd(_ i: Index) -> Bool
}


public struct SelectionNavigator<Selection, DataSource> where Selection: NavigableSelection, DataSource: SelectionNavigationDataSource, Selection.Index == DataSource.Index {
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
            var i = extending ? selection.head : selection.lowerBound
            if i > dataSource.startIndex {
                i = dataSource.index(beforeCharacter: i)
            }
            var range = dataSource.range(for: .word, enclosing: i)

            assert(!range.isEmpty)
            // range could be either pointing to whitespace, or pointing to a word. If it's the former, and we're not at the
            // beginning of the document, we need to move left one more time.
            if dataSource.startIndex < range.lowerBound && dataSource.isWordEnd(range.lowerBound) {
                range = dataSource.range(for: .word, enclosing: dataSource.index(beforeCharacter: range.lowerBound))
            }

            if extending && selection.isRange && selection.affinity == .downstream {
                // if we're shrinking the selection to the left, don't move past the anchor
                head = max(range.lowerBound, selection.anchor)
            } else {
                head = range.lowerBound
            }
            // dataSource can't be empty, so moving left can't cause an affinity of .upstream
            affinity = .downstream
        case .rightWord:
            var range = dataSource.range(for: .word, enclosing: extending ? selection.head : selection.upperBound)
            assert(!range.isEmpty)

            // range could be either pointing to whitespace, or pointing to a word. If it's the former, and we're not at the
            // end of the document, we need to move right one more time.
            if range.upperBound < dataSource.endIndex && dataSource.isWordStart(range.upperBound) {
                range = dataSource.range(for: .word, enclosing: range.upperBound)
            }

            if extending && selection.isRange && selection.affinity == .upstream {
                // if we're shrinking the selection to the right, don't move past the anchor
                head = min(selection.anchor, range.upperBound)
            } else {
                head = range.upperBound
            }
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .beginningOfLine:
            let target = selection.lowerBound
            let targetAffinity = selection.isCaret ? selection.affinity : .downstream

            let lineRange = dataSource.range(for: .paragraph, enclosing: target)
            if target == lineRange.lowerBound {
                head = lineRange.lowerBound
            } else {
                var fragRange = dataSource.range(for: .line, enclosing: target)

                if targetAffinity == .upstream && target == fragRange.lowerBound && dataSource.startIndex < fragRange.lowerBound {
                    fragRange = dataSource.range(for: .line, enclosing: dataSource.index(beforeCharacter: target))
                }
                head = fragRange.lowerBound
            }

            // Even though we're moving left, if the line is the empty last line, we could be
            // at endIndex and need an upstream affinity.
            affinity = head == dataSource.endIndex ? .upstream : .downstream
        case .endOfLine:
            let target = selection.upperBound
            let targetAffinity = selection.isCaret ? selection.affinity : .upstream

            let lineRange = dataSource.range(for: .paragraph, enclosing: target)
            var fragRange = dataSource.range(for: .line, enclosing: target)
            if targetAffinity == .upstream && target == fragRange.lowerBound && lineRange.lowerBound < fragRange.lowerBound {
                fragRange = dataSource.range(for: .line, enclosing: dataSource.index(beforeCharacter: target))
            }

            let hardBreak = dataSource.lastCharacter(inRange: fragRange) == "\n"
            head = hardBreak ? dataSource.index(beforeCharacter: fragRange.upperBound) : fragRange.upperBound
            affinity = hardBreak ? .downstream : .upstream
        case .beginningOfParagraph:
            head = dataSource.range(for: .paragraph, enclosing: selection.lowerBound).lowerBound
            affinity = .downstream
        case .endOfParagraph:
            let i = dataSource.range(for: .paragraph, enclosing: selection.upperBound).upperBound
            if i == dataSource.endIndex && dataSource.lastCharacter(inRange: dataSource.documentRange) != "\n" {
                head = i
            } else {
                head = dataSource.index(beforeCharacter: i)
            }


            // end of document is end of last paragraph. This is
            // necessary so that we can distingush this case from
            // moving to the end of the second to last paragraph
            // when the last paragraph is an empty last line.
            // if selection.upperBound == dataSource.endIndex {
            //     head = dataSource.endIndex
            // } else {
            //     let i = dataSource.index(afterLine: selection.upperBound, clampedTo: dataSource.endIndex)
            //     if i == dataSource.endIndex && dataSource.lastCharacter(inRange: dataSource.documentRange) != "\n" {
            //         head = i
            //     } else {
            //         head = dataSource.index(beforeCharacter: i)
            //     }
            // }
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
//        let affinity: Selection.Affinity
//        if i == dataSource.endIndex {
//            affinity = .upstream
//        } else if selection.isCaret {
//            affinity = selection.affinity
//        } else if movingUp {
//            affinity = .downstream
//        } else {
//            affinity = .upstream
//        }

        var fragRange = dataSource.range(for: .line, enclosing: i)
        if fragRange.lowerBound == i && selection.isCaret && selection.affinity == .upstream {
            assert(i != dataSource.startIndex)
            // If we have a caret at the end of a line fragment, we need to ask the data source
            // for the previous fragment.
            fragRange = dataSource.range(for: .line, enclosing: dataSource.index(beforeCharacter: i))
        }
        // TODO: there's still the !movingUp use upstream affinity case, but I don't remember why that's there.

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

        let xOffset = selection.xOffset ?? dataSource.caretOffset(forCharacterAt: i, inLineFragmentWithRange: fragRange)

        let target = movingUp ? dataSource.index(beforeCharacter: fragRange.lowerBound) : fragRange.upperBound
        let targetFragRange = dataSource.range(for: .line, enclosing: target)
        let head = dataSource.index(forCaretOffset: xOffset, inLineFragmentWithRange: targetFragRange)

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

    func index(afterParagraph i: Index, clampedTo limit: Index) -> Index {
        if i >= limit {
            return limit
        }
        return index(afterParagraph: i)
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

    func range(for granularity: SelectionGranularity, enclosing i: Index) -> Range<Index> {
        if isEmpty {
            return startIndex..<startIndex
        }

        switch granularity {
        case .character:
            var start = i
            if i == endIndex {
                start = index(beforeCharacter: start)
            }

            return start..<index(afterCharacter: start)
        case .word:
            let start: Index
            let end: Index

            if i == endIndex {
                start = index(ofWordBoundaryBefore: i)
                end = endIndex
            } else if isWordBoundary(i) {
                start = i
                end = index(ofWordBoundaryAfter: i)
            } else {
                start = index(roundedDownToWordBoundary: i)
                end = index(roundedUpToWordBoundary: i)
            }

            return start..<end
        case .line:
            return lineFragmentRange(containing: i)
        case .paragraph:
            let start = index(roundedDownToParagraph: i)
            let end = index(afterParagraph: i, clampedTo: endIndex)
            return start..<end
        }
    }

    func index(ofWordBoundaryBefore i: Index) -> Index {
        precondition(i > startIndex)
        var j = i
        while i > startIndex {
            j = index(beforeCharacter: j)
            if isWordBoundary(j) {
                break
            }
        }
        return j
    }

    func index(ofWordBoundaryAfter i: Index) -> Index {
        precondition(i < endIndex)
        var j = i
        while j < endIndex {
            j = index(afterCharacter: j)
            if isWordBoundary(j) {
                break
            }
        }
        return j
    }

    func index(roundedDownToWordBoundary i: Index) -> Index {
        if isWordBoundary(i) {
            return i
        }
        return index(ofWordBoundaryBefore: i)
    }

    func index(roundedUpToWordBoundary i: Index) -> Index {
        if isWordBoundary(i) {
            return i
        }
        return index(ofWordBoundaryAfter: i)
    }

    func isWordBoundary(_ i: Index) -> Bool {
        i == startIndex || i == endIndex || isWordStart(i) || isWordEnd(i)
    }

    func isWhitespace(_ i: Index) -> Bool {
        let c = self[i]
        return c.isWhitespace || c.isPunctuation
    }

    func index(roundedDownToParagraph i: Index) -> Index {
        if isParagraphBoundary(i) {
            return i
        }
        return index(beforeParagraph: i)
    }

    func isParagraphBoundary(_ i: Index) -> Bool {
        i == startIndex || self[index(beforeCharacter: i)] == "\n"
    }

    func caretOffset(forCharacterAt target: Index, inLineFragmentWithRange fragRange: Range<Index>) -> CGFloat {
        assert(fragRange == lineFragmentRange(containing: fragRange.lowerBound))
        
        // if the fragment ends in a newline, we are not allowed to ask for the caret offset
        // at the upper bound of the frag range.
        assert(lastCharacter(inRange: fragRange) != "\n" || target != fragRange.upperBound)

        var caretOffset: CGFloat?
        enumerateCaretOffsetsInLineFragment(containing: fragRange.lowerBound) { offset, i, leadingEdge in
            if target == i && leadingEdge {
                caretOffset = offset
                return false
            }

            // If our target is fragRange.upperBound, that means we're at the "upstream" position
            // at the end of this line fragment.
            if target == fragRange.upperBound && i == index(beforeCharacter: fragRange.upperBound) && !leadingEdge {
                caretOffset = offset
                return false
            }

            return true
        }

        return caretOffset!
    }

    // returns the index that's closest to xOffset (i.e. xOffset gets rounded to the nearest character)
    func index(forCaretOffset targetOffset: CGFloat, inLineFragmentWithRange fragRange: Range<Index>) -> Index {
        assert(fragRange == lineFragmentRange(containing: fragRange.lowerBound))

        let endsInNewline = lastCharacter(inRange: fragRange) == "\n"

        var res: Index?
        var prev: (offset: CGFloat, i: Index)?
        enumerateCaretOffsetsInLineFragment(containing: fragRange.lowerBound) { offset, i, leadingEdge in
            // Enumerating over the first line fragment of each string:
            // ""    -> [(0.0, 0, leading)]
            // "\n"  -> [(0.0, 0, leading)]
            // "a"   -> [(0.0, 0, leading), (8.0, 0, trailing)]
            // "a\n" -> [[0.0, 0, leading), (8.0, 0, trailing)]
            // "ab"  -> [(0.0, 0, leading), (8.0, 0, trailing), (8.0, 1, leading), (16.0, 2, trailing)]

            let nleft = distance(from: i, to: fragRange.upperBound)
            if !leadingEdge && !(nleft == 1 || (endsInNewline && nleft == 2)) {
                // skip trailing edges we're at the final trailing edge
                return true
            }

            if offset < targetOffset {
                prev = (offset, i)
                return true
            }

            if let prev {
                if abs(offset - targetOffset) > abs(prev.offset - targetOffset) {
                    res = prev.i
                } else if !leadingEdge {
                    // Unless the frag is "" or "\n", the final caret offset is a trailing edge
                    // of the last non-newline character. But we always want to return the index
                    // of the leading edge, so we increment.
                    assert(endsInNewline && nleft == 2 || nleft == 1)
                    res = index(afterCharacter: i)
                } else {
                    res = i
                }
            } else {
                res = i
            }

            return false
        }

        if let res {
            return res
        }

        // If we didn't find an index, it's because we're past the end of the line fragment.
        // In that case, return the upper bound of fragRange, with one exception: if the
        // fragment ends in a newline, return the index of the newline – it's impossible
        // to be on the leading edge of a newline character.
        if lastCharacter(inRange: fragRange) == "\n" {
            return index(beforeCharacter: fragRange.upperBound)
        } else {
            return fragRange.upperBound
        }
    }
}

// MARK: Default implementations
extension SelectionNavigationDataSource {
    func index(beforeParagraph i: Index) -> Index {
        // i is at a paragraph boundary if i == startIndex or self[i-1] == "\n"
        // if we're in the middle of a paragraph, we need to move down to the beginning
        // of that paragraph. If we're at the beginning of a paragraph, we need to move
        // down to the beginning of the previous paragraph.
        
        precondition(i > startIndex)

        // deal with the possibility that we're already at the beginning of a paragraph.
        // in this case, we have to go to the beginning of the previous paragraph

        var j = i
        if self[index(beforeCharacter: j)] == "\n" {
            j = index(beforeCharacter: j)
        }

        while j > startIndex && self[index(beforeCharacter: j)] != "\n" {
            j = index(beforeCharacter: j)
        }

        return j
    }

    func index(afterParagraph i: Index) -> Index {
        precondition(i < endIndex)

        var j = i
        while j < endIndex && self[j] != "\n" {
            j = index(afterCharacter: j)
        }

        if j < endIndex {
            j = index(afterCharacter: j)
        }

        return j
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

    func hasWordBoundary(at i: Index) -> Bool {
        if i == startIndex || i == endIndex {
            return true
        }

        let prev = index(beforeCharacter: i)
        return isWordCharacter(self[prev]) != isWordCharacter(self[i])
    }

    func isWordStart(_ i: Index) -> Bool {
        assert(!isEmpty)
        if i == endIndex {
            return false
        }

        if i == startIndex {
            return !isWhitespace(i)
        }
        let prev = index(beforeCharacter: i)
        return isWhitespace(prev) && !isWhitespace(i)
    }

    func isWordEnd(_ i: Index) -> Bool {
        assert(!isEmpty)
        if i == startIndex {
            return false
        }

        let prev = index(beforeCharacter: i)
        if i == endIndex {
            return !isWhitespace(prev)
        }
        return !isWhitespace(prev) && isWhitespace(i)
    }
}

