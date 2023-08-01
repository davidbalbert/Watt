//
//  IntervalCache.swift
//  Watt
//
//  Created by David Albert on 7/31/23.
//

import Foundation

struct IntervalCache<T> {
    var spans: Spans<T>

    init(upperBound: Int) {
        let b = SpansBuilder<T>(totalCount: upperBound)
        spans = b.build()
    }

    init(_ spans: Spans<T>) {
        self.spans = spans
    }

    var upperBound: Int {
        spans.count
    }

    var count: Int {
        spans.spanCount
    }

    var isEmpty: Bool {
        count == 0
    }

    subscript(position: Int) -> T? {
        precondition(position >= 0 && position < spans.count)

        let i = BTree.Index(offsetBy: position, in: spans.t)
        guard let (leaf, offset) = i.read() else {
            return nil
        }

        return leaf.spans.first(where: { $0.range.contains(offset) })?.data
    }

    // Returns a cache of the same size, but only with the spans that
    // overlap bounds.
    subscript(bounds: Range<Int>) -> IntervalCache {
        precondition(bounds.lowerBound >= 0 && bounds.upperBound <= spans.count)

        let i = BTree.Index(offsetBy: bounds.lowerBound, in: spans.t)
        let j = BTree.Index(offsetBy: bounds.upperBound, in: spans.t)

        let (startLeaf, startOffset) = i.read()!
        let (endLeaf, endOffset) = j.read()!

        let start: Int
        if let span = startLeaf.spans.first(where: { $0.range.contains(startOffset) }) {
            start = i.offsetOfLeaf + span.range.lowerBound
        } else {
            start = bounds.lowerBound
        }

        let end: Int
        if let span = endLeaf.spans.first(where: { $0.range.contains(endOffset) }) {
            end = j.offsetOfLeaf + span.range.upperBound
        } else {
            end = bounds.upperBound
        }

        var b = BTree<SpansSummary<T>>.Builder()
        var prefix = SpansBuilder<T>(totalCount: start).build().t
        b.push(&prefix.root)

        var t = spans.t
        b.push(&t.root, slicedBy: start..<end)

        var suffix = SpansBuilder<T>(totalCount: spans.count - end).build().t
        b.push(&suffix.root)

        return IntervalCache(Spans(BTree(b.build())))
    }

    mutating func set(_ value: T, forRange range: Range<Int>) {
        var sb = SpansBuilder<T>(totalCount: spans.count)
        sb.add(value, covering: range)
        let new = sb.build()

        self.spans = spans.merging(new) { $0 ?? $1 }
    }

    mutating func invalidate(range: Range<Int>) {
        precondition(range.lowerBound >= 0 && range.upperBound <= spans.count)

        let i = BTree.Index(offsetBy: range.lowerBound, in: spans.t)
        let j = BTree.Index(offsetBy: range.upperBound, in: spans.t)

        let (startLeaf, startOffset) = i.read()!
        let (endLeaf, endOffset) = j.read()!

        let start = startLeaf.spans.first(where: { $0.range.contains(startOffset) })?.range.lowerBound ?? range.lowerBound
        let end = endLeaf.spans.first(where: { $0.range.contains(endOffset) })?.range.upperBound ?? range.upperBound

        var b = BTree<SpansSummary<T>>.Builder()

        var t = spans.t
        b.push(&t.root, slicedBy: 0..<start)

        var new = SpansBuilder<T>(totalCount: range.count).build().t.root
        b.push(&new)

        b.push(&t.root, slicedBy: end..<spans.count)

        self.spans = Spans(BTree(b.build()))
    }

    mutating func removeAll() {
        guard count > 0 else {
            return
        }

        let b = SpansBuilder<T>(totalCount: spans.count)
        spans = b.build()
    }
}

