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
    func index(beforeParagraph i: Index) -> Index
    func index(afterParagraph i: Index) -> Index
}

// MARK: - Default implementations

public extension DocumentContentDataSource {
    func index(beforeParagraph i: Index) -> Index {
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

    func index(afterParagraph i: Index) -> Index {
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

    func index(roundedDownToParagraph i: Index) -> Index {
        if i == startIndex || self[index(before: i)] == "\n" {
            return i
        }
        return index(beforeParagraph: i)
    }

    func index(roundedUpToParagraph i: Index) -> Index {
        if i == endIndex || self[index(before: i)] == "\n" {
            return i
        }
        return index(afterParagraph: i)
    }

}
