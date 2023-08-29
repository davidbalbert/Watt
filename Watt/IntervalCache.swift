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
        spans.upperBound
    }

    var count: Int {
        spans.count
    }

    var isEmpty: Bool {
        count == 0
    }

    subscript(position: Int) -> T? {
        precondition(position >= 0 && position <= spans.upperBound)

        let i = BTree.Index(offsetBy: position, in: spans.t)
        guard let (leaf, offset) = i.read() else {
            return nil
        }

        return leaf.spans.first(where: { $0.range.contains(offset) || $0.range.isEmpty && $0.range.lowerBound == position })?.data
    }

    func range(forSpanContaining position: Int) -> Range<Int>? {
        precondition(position >= 0 && position <= spans.upperBound)

        let i = BTree.Index(offsetBy: position, in: spans.t)
        guard let (leaf, offset) = i.read() else {
            return nil
        }

        let range = leaf.spans.first(where: { $0.range.contains(offset) || $0.range.isEmpty && $0.range.lowerBound == position })?.range

        guard let range else {
            return nil
        }

        return (i.offsetOfLeaf + range.lowerBound)..<(i.offsetOfLeaf + range.upperBound)
    }

    // Returns a cache of the same size, but only with the spans that
    // overlap bounds.
    subscript(bounds: Range<Int>) -> IntervalCache {
        precondition(bounds.lowerBound >= 0 && bounds.upperBound <= spans.upperBound)

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

        var suffix = SpansBuilder<T>(totalCount: spans.upperBound - end).build().t
        b.push(&suffix.root)

        return IntervalCache(Spans(BTree(b.build())))
    }

    mutating func set(_ value: T, forRange range: Range<Int>) {
        var sb = SpansBuilder<T>(totalCount: spans.upperBound)
        sb.add(value, covering: range)
        let new = sb.build()

        self.spans = spans.merging(new) { $0 ?? $1 }
    }

    mutating func invalidate<Summary>(delta: BTree<Summary>.Delta) where Summary: BTreeSummary {
        var b = BTree<SpansSummary<T>>.Builder()

        var prev: BTree<Summary>.DeltaElement? = nil

        // precondition: invalidatedThrough will always be 0 or
        // the upperBound of a span.
        var invalidatedThrough = 0
        for (i, el) in delta.elements.enumerated() {
            switch el {
            case let .copy(start, end):
                let next = i == delta.elements.count-1 ? nil : delta.elements[i+1]

                let didInsert = prev != nil && prev!.isInsert
                let willInsert = next != nil && next!.isInsert

                // -1 because end is exclusive, and if we're at a boundary between
                // spans, we'd like to get the span where end is still exclusive – i.e.
                // where end is at the end of the span, rather than the start.
                let firstRange = range(forSpanContaining: start)
                let lastRange = range(forSpanContaining: end-1)

                let prefix: Int
                let copyStart: Int
                let copyEnd: Int
                let suffix: Int

                if invalidatedThrough > end {
                    prefix = end - start
                    copyStart = 0
                    copyEnd = 0
                    suffix = 0
                } else if invalidatedThrough > start, let lastRange {
                    prefix = invalidatedThrough - start
                    copyStart = invalidatedThrough

                    if lastRange.upperBound == end && !willInsert {
                        copyEnd = lastRange.upperBound
                    } else {
                        copyEnd = lastRange.lowerBound
                    }

                    suffix = copyEnd == end || firstRange == lastRange ? 0 : end - copyEnd

                    invalidatedThrough = lastRange.upperBound
                } else if invalidatedThrough > start {
                    prefix = invalidatedThrough - start
                    copyStart = invalidatedThrough
                    copyEnd = end
                    suffix = 0
                } else {
                    if let firstRange, (start > firstRange.lowerBound || didInsert) {
                        prefix = min(firstRange.upperBound, end) - start
                        copyStart = firstRange.upperBound
                        invalidatedThrough = firstRange.upperBound
                    } else {
                        prefix = 0
                        copyStart = start
                    }

                    if let lastRange, (prefix == 0 || lastRange != firstRange) && (end < lastRange.upperBound || willInsert) {
                        copyEnd = lastRange.lowerBound
                        suffix = end - max(lastRange.lowerBound, start)
                        invalidatedThrough = lastRange.upperBound
                    } else {
                        copyEnd = end
                        suffix = 0
                    }
                }

                if prefix > 0 {
                    var blank = SpansBuilder<T>(totalCount: prefix).build()
                    b.push(&blank.t.root)
                }

                if copyStart < copyEnd {
                    var r = spans.t.root
                    b.push(&r, slicedBy: copyStart..<copyEnd)
                }

                if suffix > 0 {
                    var blank = SpansBuilder<T>(totalCount: suffix).build()
                    b.push(&blank.t.root)
                }
            case let .insert(node):
                var s = SpansBuilder<T>(totalCount: node.count).build()
                b.push(&s.t.root)
            }

            prev = el
        }

        spans = Spans(BTree(b.build()))
    }

    mutating func removeAll() {
        guard count > 0 else {
            return
        }

        let b = SpansBuilder<T>(totalCount: spans.upperBound)
        spans = b.build()
    }
}
