//
//  Spans.swift
//  Watt
//
//  Created by David Albert on 8/1/23.
//

import Foundation

struct Span<T> {
    var range: Range<Int>
    var data: T
}

extension Span: Equatable where T: Equatable {
}

struct SpansLeaf<T>: BTreeLeaf {
    static var minSize: Int { 32 }
    static var maxSize: Int { 64 }

    var count: Int
    var spans: [Span<T>]

    init() {
        count = 0
        spans = []
    }

    init(count: Int, spans: [Span<T>]) {
        self.count = count
        self.spans = spans
    }

    static var zero: SpansLeaf {
        SpansLeaf()
    }

    var isUndersized: Bool {
        spans.count < SpansLeaf.minSize
    }

    mutating func pushMaybeSplitting(other: SpansLeaf) -> SpansLeaf? {
        for span in other.spans {
            let range = span.range.offset(by: count)
            spans.append(Span(range: range, data: span.data))
        }
        count += other.count

        if spans.count <= SpansLeaf.maxSize {
            return nil
        } else {
            let splitIndex = spans.count / 2
            let splitCount = spans[splitIndex].range.lowerBound

            var new = Array(spans[splitIndex...])
            for i in 0..<new.count {
                new[i].range = new[i].range.offset(by: -splitCount)
            }
            let newCount = count - splitCount

            spans.removeLast(new.count)
            count = splitCount

            return SpansLeaf(count: newCount, spans: new)
        }
    }

    subscript(bounds: Range<Int>) -> SpansLeaf {
        var s: [Span<T>] = []
        for span in spans {
            let range = span.range.clamped(to: bounds).offset(by: -bounds.lowerBound)

            if !range.isEmpty {
                s.append(Span(range: range, data: span.data))
            }
        }

        return SpansLeaf(count: bounds.count, spans: s)
    }
}

struct SpansSummary<T>: BTreeSummary {
    static func += (left: inout SpansSummary<T>, right: SpansSummary<T>) {
        left.spans += right.spans
        left.range = left.range.union(right.range)
    }

    static var zero: SpansSummary<T> {
        SpansSummary()
    }

    var spans: Int
    var range: Range<Int>

    init() {
        self.spans = 0
        self.range = 0..<0
    }

    init(summarizing leaf: SpansLeaf<T>) {
        spans = leaf.spans.count

        var range = 0..<0
        for span in leaf.spans {
            range = range.union(span.range)
        }

        self.range = range
    }
}

struct Spans<T> {
    var t: BTree<SpansSummary<T>>

    var count: Int {
        // TODO: once we make Rope, etc. wrap BTree, then
        // we can define BTree/count directly.
        t.root.count
    }

    var spanCount: Int {
        t.root.summary.spans
    }

    init(_ tree: BTree<SpansSummary<T>>) {
        self.t = tree
    }

    // Returns data covering the given range if there is a single Span
    // that covers the entire range. Otherwise returns nil.
    func data(covering range: Range<Int>) -> T? {
        var i = BTree.Index(offsetBy: range.lowerBound, in: t)
        guard let (leaf, _) = i.read() else {
            return nil
        }

        let r = range.offset(by: -i.offsetOfLeaf)
        for span in leaf.spans {
            if span.range == r {
                return span.data
            }
        }

        return nil
    }

    func merging<O>(_ other: Spans<T>, transform: (T?, T?) -> O?) -> Spans<O> {
        precondition(count == other.count)

        var sb = SpansBuilder<O>(totalCount: count)

        var left = self.makeIterator()
        var right = other.makeIterator()

        var nextLeft = left.next()
        var nextRight = right.next()

        while true {
            if nextLeft == nil && nextRight == nil {
                break
            } else if nextLeft == nil {
                let span = nextRight!

                if let transformed = transform(nil, span.data) {
                    sb.add(transformed, covering: span.range)
                }

                while let span = right.next() {
                    if let transformed = transform(nil, span.data) {
                        sb.add(transformed, covering: span.range)
                    }
                }

                break

            } else if nextRight == nil {
                let span = nextLeft!

                if let transformed = transform(span.data, nil) {
                    sb.add(transformed, covering: span.range)
                }

                while let span = left.next() {
                    if let transformed = transform(span.data, nil) {
                        sb.add(transformed, covering: span.range)
                    }
                }

                break
            }

            let spanLeft = nextLeft!
            let spanRight = nextRight!

            var rangeLeft = spanLeft.range
            var rangeRight = spanRight.range

            if !rangeLeft.overlaps(rangeRight) {
                if rangeLeft.lowerBound < rangeRight.lowerBound {
                    if let transformed = transform(spanLeft.data, nil) {
                        sb.add(transformed, covering: rangeLeft)
                    }
                    nextLeft = left.next()
                } else {
                    if let transformed = transform(spanRight.data, nil) {
                        sb.add(transformed, covering: rangeRight)
                    }
                    nextRight = right.next()
                }

                continue
            }

            if rangeLeft.lowerBound < rangeRight.lowerBound {
                let prefix = rangeLeft.prefix(rangeRight)
                if let transformed = transform(spanLeft.data, nil) {
                    sb.add(transformed, covering: prefix)
                }
                rangeLeft = rangeLeft.suffix(prefix)
            } else if rangeRight.lowerBound < rangeLeft.lowerBound {
                let prefix = rangeRight.prefix(rangeLeft)
                if let transformed = transform(spanRight.data, nil) {
                    sb.add(transformed, covering: prefix)
                }
                rangeRight = rangeRight.suffix(prefix)
            }

            assert(rangeLeft.lowerBound == rangeRight.lowerBound)

            let intersection = rangeLeft.clamped(to: rangeRight)
            assert(!intersection.isEmpty)
            if let transformed = transform(spanLeft.data, spanRight.data) {
                sb.add(transformed, covering: intersection)
            }

            rangeLeft = rangeLeft.suffix(intersection)
            rangeRight = rangeRight.suffix(intersection)

            if rangeLeft.isEmpty {
                nextLeft = left.next()
            } else {
                nextLeft = Span(range: rangeLeft, data: spanLeft.data)
            }

            if rangeRight.isEmpty {
                nextRight = right.next()
            } else {
                nextRight = Span(range: rangeRight, data: spanRight.data)
            }
        }

        return sb.build()
    }
}

extension Spans: Sequence {
    struct Iterator: IteratorProtocol {
        var i: BTree<SpansSummary<T>>.Index
        var ii: Int

        init(_ spans: Spans<T>) {
            self.i = spans.t.startIndex
            self.ii = 0
        }

        mutating func next() -> Span<T>? {
            guard let (leaf, _) = i.read() else {
                return nil
            }

            if leaf.spans.isEmpty {
                return nil
            }

            let span = leaf.spans[ii]
            let offsetOfLeaf = i.offsetOfLeaf
            ii += 1
            if ii == leaf.spans.count {
                _ = i.nextLeaf()
                ii = 0
            }

            return Span(range: span.range.offset(by: offsetOfLeaf), data: span.data)
        }
    }

    func makeIterator() -> Iterator {
        Iterator(self)
    }
}


struct SpansBuilder<T> {
    var b: BTree<SpansSummary<T>>.Builder
    var leaf: SpansLeaf<T>
    var count: Int
    var totalCount: Int

    init(totalCount: Int) {
        self.b = BTree<SpansSummary>.Builder()
        self.leaf = SpansLeaf()
        self.count = 0
        self.totalCount = totalCount
    }

    mutating func add(_ data: T, covering range: Range<Int>) {
        precondition(range.lowerBound >= count + (leaf.spans.last?.range.upperBound ?? 0))

        if leaf.spans.count == SpansLeaf<T>.maxSize {
            leaf.count = range.lowerBound - count
            self.count = range.lowerBound
            b.push(leaf: leaf)
            leaf = SpansLeaf()
        }

        leaf.spans.append(Span(range: range.offset(by: -count), data: data))
        totalCount = Swift.max(totalCount, range.upperBound)
    }

    consuming func build() -> Spans<T> {
        leaf.count = totalCount - count
        b.push(leaf: leaf)

        return Spans(BTree(b.build()))
    }
}

fileprivate extension Range {
    func union(_ other: Range<Bound>) -> Range<Bound> {
        let start = Swift.min(lowerBound, other.lowerBound)
        let end = Swift.max(upperBound, other.upperBound)

        return start..<end
    }

    // The porton of `self` that comes before `other`.
    // If `other` starts before `self`, returns an empty
    // starting at other.lowerBounds.
    func prefix(_ other: Range) -> Range {
        return Swift.min(lowerBound, other.lowerBound)..<Swift.min(upperBound, other.lowerBound)
    }

    // The portion of `self` that comes after `other`.
    // If `other` ends after `self`, returns an empty
    // range ending at other.upperBound.
    func suffix(_ other: Range) -> Range {
        return Swift.max(lowerBound, other.upperBound)..<Swift.max(upperBound, other.upperBound)
    }
}
