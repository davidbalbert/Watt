//
//  Transposer.swift
//
//
//  Created by David Albert on 11/15/23.
//

import Foundation

public enum Transposer<DataSource> where DataSource: DocumentContentDataSource {
    public typealias Index = DataSource.Index

    public static func indicesForTranspose(inSelectedRange range: Range<Index>, dataSource: DataSource) -> (Index, Index)? {
        if dataSource.characterCount < 2 {
            return nil
        }

        guard range.isEmpty || dataSource.distance(from: range.lowerBound, to: range.upperBound) == 2 else {
            return nil
        }

        let i: DataSource.Index
        let lineStart = dataSource.index(roundedDownToParagraph: range.lowerBound)

        if !range.isEmpty {
            i = range.lowerBound
        } else if lineStart == range.lowerBound {
            i = lineStart
        } else if range.lowerBound == dataSource.endIndex {
            i = dataSource.index(range.lowerBound, offsetBy: -2)
        } else {
            i = dataSource.index(before: range.lowerBound)
        }

        return (i, dataSource.index(after: i))
    }

    // Swap two words, and select them at the end. If there's
    // a selection that covers exactly two words, swap them.
    // If there's a caret, expand outwards to find the words to
    // swap. If we're in leading or trailing whitespace, there's
    // nothing to swap. If we're in the last word of the document,
    // swap that, plus the previous word. If we're in whitespace
    // between two words, swap those. Otherwise swap the word we're
    // in and the next word.
    //
    // Suggested improvements:
    // - A single word surrounded by matching punctuation should treat the punctuation as part of the word.
    //   E.g. "foo", 'foo', “foo”, ‘foo’, (foo), [foo], <foo>, etc.
    // - Punctuated numbers should be considered a single word.
    //   E.g. 1,000,000.00 and 1.000.000,00
    public static func rangesForTransposeWords(inSelectedRange range: Range<Index>, dataSource: DataSource) -> (Range<Index>, Range<Index>)? {
        if dataSource.isEmpty {
            return nil
        }

        let word1: Range<Index>
        let word2: Range<Index>

        if range.isEmpty {
            guard let (w1, w2) = rangesForTransposeWords(containing: range.lowerBound, dataSource: dataSource) else {
                return nil
            }

            word1 = w1
            word2 = w2
        } else {
            guard let (w1, w2) = rangesForTransposeWords(exactlyCoveredBy: range, dataSource: dataSource) else {
                return nil
            }

            word1 = w1
            word2 = w2
        }

        return (word1, word2)
    }

    static func rangesForTransposeWords(containing position: Index, dataSource: DataSource) -> (Range<Index>, Range<Index>)? {
        if dataSource.isEmpty {
            return nil
        }

        if position == dataSource.endIndex && !dataSource.isWordEnd(dataSource.endIndex) {
            return nil
        }
        if position == dataSource.startIndex && !dataSource.isWordStart(dataSource.startIndex) {
            return nil
        }

        let word: Range<Index>
        if let w = dataSource.wordRange(containing: position) {
            word = w
        } else {
            // we're in whitespace, so search forward for the next word
            if let start = dataSource.index(beginningOfWordAfter: position) {
                // we found a word searching forward
                word = dataSource.wordRange(containing: start)!
            } else if dataSource.isWordEnd(position) {
                // a special case, we're in trailing whitespace, but the character right before where we started is
                // a word, so we'll transpose that word with the one previous.
                word = dataSource.wordRange(containing: dataSource.index(before: position))!
            } else {
                // we're in trailing whitespace, and there's nothing to transpose
                return nil
            }
        }

        // We know word is word2 if:
        // - We we started in whitespace (position < word.lowerBound)
        // - We are at the start of the word we found, which is treated as whitespace (position == word.lowerBound)
        // - We were at the end of the last word in the document
        if position <= word.lowerBound || dataSource.isWordEnd(position) {
            // TODO: start here, and continue forward reviewing and simplifying the code.

            let word2 = word
            var i = word2.lowerBound
            while i > dataSource.startIndex {
                let prev = dataSource.index(before: i)
                if dataSource.isWordCharacter(prev) {
                    break
                }
                i = prev
            }

            if i == dataSource.startIndex && dataSource.isWordStart(position) {
                // There was no previous word, but we were at the beginning
                // of a word, so we can search fowards instead. Just
                // fall through
            } else if i == dataSource.startIndex {
                // there was a single word, so there's nothing to transpose
                return nil
            } else {
                // we found a word searching backwards
                let word1 = dataSource.wordRange(containing: dataSource.index(before: i))!

                return (word1, word2)
            }
        }

        // We started in the middle of a word (or at the beginning
        // of the first word). We need to figure out if we're
        // word1 or word2. First we assume we're the first word, which
        // is most common, and we search forwards for the second word
        var i = word.upperBound
        while i < dataSource.endIndex && !dataSource.isWordCharacter(i) {
            i = dataSource.index(after: i)
        }

        // the more common case. word is the first word, and
        // i is pointing at the beginning of the second word
        if i < dataSource.endIndex {
            let word1 = word
            let word2 = dataSource.wordRange(containing: i)!

            return (word1, word2)
        }

        // we didn't find a word going forward, so, now we assume
        // we're the second word, and we search backwards. This is
        // uncommon.
        let word2 = word
        i = word2.lowerBound
        while i > dataSource.startIndex {
            let prev = dataSource.index(before: i)
            if dataSource.isWordCharacter(prev) {
                break
            }
            i = prev
        }

        // there was a single word, so there's nothing to transpose
        if i == dataSource.startIndex { return nil }

        let word1 = dataSource.wordRange(containing: dataSource.index(before: i))!

        return (word1, word2)
    }

    static func rangesForTransposeWords(exactlyCoveredBy range: Range<Index>, dataSource: DataSource) -> (Range<Index>, Range<Index>)? {
        guard dataSource.isWordStart(range.lowerBound) && dataSource.isWordEnd(range.upperBound) else {
            return nil
        }

        let limit = range.upperBound

        let start1 = range.lowerBound
        var i = start1

        while i < limit && dataSource.isWordCharacter(i) {
            i = dataSource.index(after: i)
        }
        if i == limit { return nil }
        let end1 = i

        while i < limit && !dataSource.isWordCharacter(i) {
            i = dataSource.index(after: i)
        }
        if i == limit { return nil }
        let start2 = i

        while i < limit && dataSource.isWordCharacter(i) {
            i = dataSource.index(after: i)
        }
        if i < limit { return nil }
        let end2 = i

        return (start1..<end1, start2..<end2)
    }
}
