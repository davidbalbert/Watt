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
        precondition(position >= 0 && position <= spans.count)

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

    mutating func invalidate<Summary>(delta: BTree<Summary>.Delta) where Summary: BTreeSummary {
        // How to invalidate using a Delta:
        // Create a new SpanBuilder. At this point, we already have to know the size of the new
        // tree (the one created by applying delta to the current tree), so this description may
        // be a bit out of order.
        //
        // Loop over each DeltaElement. Spaces between a space between two copies is a deletion.
        // We need to take each deletion range, expand it so that its lower and upper bounds
        // don't fall inside a span, and then insert an empty span at that range. We're going to
        // have an index i, that starts at 0, and we'll advance as we go.
        //
        // There's nuance to the size of the empty span that we insert. If the deletion range was
        // 1, but it's inside of a span of length 10, the expanded range will be of length 10. But
        // we don't insert an empty span of length 10. Instead we insert an empty span of length 9.
        // This simultaneously invalidates the entire line that was there before, and also takes
        // the deletion into account.
        //
        // But! When we advance i, we have to advance it by 10, not 9, because i is an index into
        // the original span.
        //
        // Insertions are a bit easier. We just insert an append an empty span of the appropriate
        // length, and don't increment i at all.

        precondition(delta.baseCount == upperBound)

        var b = BTree<SpansSummary<T>>.Builder()

        var newCount = 0
        for i in 0..<delta.elements.count {
            let el = delta.elements[i]

            switch el {
            case let .copy(start, end):
                assert(end > start)

                let firstLine = nonOverlappingRange(expanding: start..<start)
                // -1 because we end is exclusive, and if we're at a boundary between
                // spans, we'd like to get the span where end is still exclusive – i.e.
                // where end is at the end of the span, rather than the start.
                let lastLine = nonOverlappingRange(expanding: (end-1)..<(end-1))

                let aheadBy = max(0, newCount - firstLine.lowerBound)

                // Add a blank span for the portion of start..<end that falls before
                // the first full line.
                if firstLine.lowerBound < aheadBy + start {
                    let count = firstLine.upperBound - start
                    var blank = SpansBuilder<T>(totalCount: count).build()
                    b.push(&blank.t.root)
                    newCount += count
                }

                let prevEl = i == 0 ? nil : delta.elements[i-1]
                let nextEl = i == delta.elements.count-1 ? nil : delta.elements[i+1]

                let insertedBefore = prevEl != nil && prevEl!.isInsert
                let willInsertAfter = nextEl != nil && nextEl!.isInsert

                // Copy any full lines covered by start..<end
                let fullLinesStart = firstLine.lowerBound == aheadBy + start && !insertedBefore ? start : firstLine.upperBound

                let fullLinesEnd: Int
                if end == upperBound && willInsertAfter {
                    // We're inserting at the very end of the cache.
                    // Invalidate the last range of the copy.
                    fullLinesEnd = lastLine.lowerBound
                } else if end == lastLine.upperBound {
                    // The copy lines up with the end of a range
                    // or the copy is outside of a range. Don't
                    // invalidate anything.
                    fullLinesEnd = lastLine.upperBound
                } else {
                    // The copy ends inside a range. Invalidate the
                    // last range of the copy.
                    fullLinesEnd = lastLine.lowerBound
                }

                var r = spans.t.root
                if fullLinesStart < fullLinesEnd {
                    b.push(&r, slicedBy: fullLinesStart..<fullLinesEnd)
                    newCount += fullLinesEnd - fullLinesStart
                }

                // Add a blank span for the portion of start..<end that falls after
                // the last full line.
                if fullLinesEnd < aheadBy + end {
                    let count = end - fullLinesEnd
                    var blank = SpansBuilder<T>(totalCount: count).build()
                    b.push(&blank.t.root)
                    newCount += count
                }
            case let .insert(node):
                var s = SpansBuilder<T>(totalCount: node.count).build()
                b.push(&s.t.root)
                newCount += node.count
            }
        }

        spans = Spans(BTree(b.build()))
    }

    // Expands range until its lower and upper bounds no longer
    // fall inside a span. N.b. if either of range's bounds are
    // between spans, they won't be modified.
    func nonOverlappingRange(expanding range: Range<Int>) -> Range<Int> {
        precondition(range.lowerBound >= 0 && range.upperBound <= spans.count)

        let i = BTree.Index(offsetBy: range.lowerBound, in: spans.t)
        let j = BTree.Index(offsetBy: range.upperBound, in: spans.t)

        let (startLeaf, startOffset) = i.read()!
        let (endLeaf, endOffset) = j.read()!

        let start = startLeaf.spans.first(where: { $0.range.contains(startOffset) })?.range.lowerBound ?? range.lowerBound - i.offsetOfLeaf
        let end = endLeaf.spans.first(where: { $0.range.contains(endOffset) })?.range.upperBound ?? range.upperBound - j.offsetOfLeaf

        return (i.offsetOfLeaf + start)..<(j.offsetOfLeaf + end)
    }

    mutating func removeAll() {
        guard count > 0 else {
            return
        }

        let b = SpansBuilder<T>(totalCount: spans.count)
        spans = b.build()
    }
}
