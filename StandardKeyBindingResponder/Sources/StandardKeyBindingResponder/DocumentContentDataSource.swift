//
//  DocumentContentDataSource.swift
//
//
//  Created by David Albert on 11/15/23.
//

import Foundation

public protocol DocumentContentDataSource {
    associatedtype Index: Comparable

    var documentRange: Range<Index> { get }

    func index(_ i: Index, offsetBy distance: Int) -> Index
    func distance(from start: Index, to end: Index) -> Int

    var characterCount: Int { get }

    subscript(index: Index) -> Character { get }

    // MARK: Paragraph navigation
    func index(ofParagraphBoundaryBefore i: Index) -> Index
    func index(ofParagraphBoundaryAfter i: Index) -> Index
}

// MARK: - Default implementations

public extension DocumentContentDataSource {
    func index(ofParagraphBoundaryBefore i: Index) -> Index {
        precondition(i > startIndex)

        var j = i
        if self[index(before: j)] == "\n" {
            j = index(before: j)
        }

        while j > startIndex && self[index(before: j)] != "\n" {
            j = index(before: j)
        }

        return j
    }

    func index(ofParagraphBoundaryAfter i: Index) -> Index {
        precondition(i < endIndex)

        var j = i
        while j < endIndex && self[j] != "\n" {
            j = index(after: j)
        }

        if j < endIndex {
            j = index(after: j)
        }

        return j
    }
}

// MARK: - Internal helpers

extension DocumentContentDataSource {
    var isEmpty: Bool {
        documentRange.isEmpty
    }

    var startIndex: Index {
        documentRange.lowerBound
    }

    var endIndex: Index {
        documentRange.upperBound
    }

    func index(before i: Index) -> Index {
        index(i, offsetBy: -1)
    }

    func index(after i: Index) -> Index {
        index(i, offsetBy: 1)
    }

    func index(roundingDownToParagraph i: Index) -> Index {
        if i == startIndex || self[index(before: i)] == "\n" {
            return i
        }
        return index(ofParagraphBoundaryBefore: i)
    }

    func paragraph(containing i: Index) -> Range<Index> {
        let start = index(roundingDownToParagraph: i)
        let end = i == endIndex ? endIndex : index(ofParagraphBoundaryAfter: i)
        return start..<end
    }

    // either endIndex or self[i] == "\n"
    func endOfParagraph(containing i: Index) -> Index {
        let r = paragraph(containing: i)
        if r.upperBound == endIndex {
            return r.upperBound
        }
        return index(before: r.upperBound)
    }

    func index(beginningOfWordBefore i: Index) -> Index? {
        if i == startIndex {
            return nil
        }

        var i = i
        if isWordStart(i) {
            i = index(before: i)
        }

        while i > startIndex && !isWordStart(i) {
            i = index(before: i)
        }

        // we got to startIndex but the first character
        // is whitespace.
        if !isWordStart(i) {
            return nil
        }

        return i
    }

    func index(beginningOfWordAfter i: Index) -> Index? {
        if i == endIndex {
            return nil
        }

        var i = i
        if isWordStart(i) {
            i = index(after: i)
        }

        while i < endIndex && !isWordStart(i) {
            i = index(after: i)
        }

        // we got to endIndex, but the last character
        // is whitespace.
        if !isWordStart(i) {
            return nil
        }

        return i
    }

    func index(endOfWordBefore i: Index) -> Index? {
        if i == startIndex {
            return nil
        }

        var i = i
        if isWordEnd(i) {
            i = index(before: i)
        }

        while i > startIndex && !isWordEnd(i) {
            i = index(before: i)
        }

        // we got to startIndex but the first character
        // is whitespace.
        if !isWordEnd(i) {
            return nil
        }

        return i
    }

    func index(endOfWordAfter i: Index) -> Index? {
        if i == endIndex {
            return nil
        }

        var i = i
        if isWordEnd(i) {
            i = index(after: i)
        }

        while i < endIndex && !isWordEnd(i) {
            i = index(after: i)
        }

        // we got to endIndex, but the last character
        // is whitespace.
        if !isWordEnd(i) {
            return nil
        }

        return i
    }

    func wordRange(containing i: Index) -> Range<Index>? {
        var i = i
        if i == endIndex {
            i = index(before: i)
        }

        let nextIsWordChar = i < index(before: endIndex) && isWordCharacter(index(after: i))
        let prevIsWordChar = i > startIndex && isWordCharacter(index(before: i))

        guard isWordCharacter(i) || (nextIsWordChar && prevIsWordChar && (self[i] == "'" || self[i] == "’")) else {
            return nil
        }

        var j = index(after: i)

        while i > startIndex && !isWordStart(i) {
            i = index(before: i)
        }

        while j < endIndex && !isWordEnd(j) {
            j = index(after: j)
        }

        return i..<j
    }

    func isWordStart(_ i: Index) -> Bool {
        if isEmpty || i == endIndex {
            return false
        }

        if i == startIndex {
            return isWordCharacter(i)
        }
        let prev = index(before: i)

        // a single apostrophy surrounded by word characters is not a word boundary
        if prev > startIndex && (self[prev] == "'" || self[prev] == "’") && isWordCharacter(index(before: prev)) {
            return false
        }

        return !isWordCharacter(prev) && isWordCharacter(i)
    }

    func isWordEnd(_ i: Index) -> Bool {
        if isEmpty || i == startIndex {
            return false
        }

        let prev = index(before: i)
        if i == endIndex {
            return isWordCharacter(prev)
        }

        // a single apostrophy surrounded by word characters is not a word boundary
        if (self[i] == "'" || self[i] == "’") && isWordCharacter(prev) && isWordCharacter(index(after: i)) {
            return false
        }

        return isWordCharacter(prev) && !isWordCharacter(i)
    }

    func isWordCharacter(_ i: Index) -> Bool {
        let c = self[i]
        return !c.isWhitespace && !c.isPunctuation
    }
}
