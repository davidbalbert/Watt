//
//  AttributedRope.swift
//  Watt
//
//  Created by David Albert on 8/27/23.
//

import AppKit

protocol AttributedRopeKey {
    associatedtype Value: Equatable
    static var name: String { get }
}

@dynamicMemberLookup
struct AttributedRope {
    var text: Rope
    var spans: Spans<Attributes>

    init() {
        self.init("")
    }

    init(_ string: String, attributes: Attributes = Attributes()) {
        self.init(Rope(string), attributes: attributes)
    }

    init(_ text: Rope, attributes: Attributes = Attributes()) {
        self.text = text

        var b = SpansBuilder<Attributes>(totalCount: text.utf8.count)
        if text.utf8.count > 0 {
            b.add(attributes, covering: 0..<text.utf8.count)
        }
        self.spans = b.build()
    }

    init(_ subrope: AttributedSubrope) {
        self.text = subrope.text[subrope.bounds]
        self.spans = subrope.spans[Range(intRangeFor: subrope.bounds)]
    }

    // internal
    init(text: Rope, spans: Spans<Attributes>) {
        assert(text.utf8.count == spans.upperBound)
        self.text = text
        self.spans = spans
    }
}

@dynamicMemberLookup
struct AttributedSubrope {
    var text: Rope
    var spans: Spans<AttributedRope.Attributes>
    var bounds: Range<AttributedRope.Index>
}

extension AttributedRope {
    @dynamicMemberLookup
    struct Attributes: Equatable {
        static func == (lhs: Attributes, rhs: Attributes) -> Bool {
            if lhs.contents.keys != rhs.contents.keys {
                return false
            }

            for (key, value) in lhs.contents {
                if !isEqual(value, rhs.contents[key]) {
                    return false
                }
            }

            return true
        }

        var contents: [String: Any]

        var count: Int {
            contents.count
        }

        init() {
            contents = [:]
        }

        init(_ contents: [String: Any]) {
            self.contents = contents
        }
    }
}

// MARK: - Runs

extension AttributedRope {
    var runs: Runs {
        Runs(base: self)
    }

    struct Runs {
        var base: AttributedRope

        var count: Int {
            base.spans.count
        }
    }
}

extension AttributedRope.Runs {
    @dynamicMemberLookup
    struct Run {
        var base: AttributedRope
        var span: Span<AttributedRope.Attributes>

        var range: Range<AttributedRope.Index> {
            Range(span.range, in: base.text)
        }

        var attributes: AttributedRope.Attributes {
            span.data
        }
    }
}

extension AttributedRope.Runs: Sequence {
    struct Iterator: IteratorProtocol {
        var i: Spans<AttributedRope.Attributes>.Iterator
        var base: AttributedRope

        init(_ runs: AttributedRope.Runs) {
            self.i = runs.base.spans.makeIterator()
            self.base = runs.base
        }

        mutating func next() -> Run? {
            guard let span = i.next() else {
                return nil
            }

            return Run(base: base, span: span)
        }
    }

    func makeIterator() -> Iterator {
        Iterator(self)
    }
}


// MARK: - Attributes

extension AttributedRope {
    struct AttributeKeys {
        var font: FontAttribute
        var foregroundColor: ForegroundColorAttribute
        var backgroundColor: BackgroundColorAttribute
        var underlineStyle: UnderlineStyleAttribute
        var underlineColor: UnderlineColorAttribute

        enum FontAttribute: AttributedRopeKey {
            typealias Value = NSFont
            static let name = NSAttributedString.Key.font.rawValue
        }

        enum ForegroundColorAttribute: AttributedRopeKey {
            typealias Value = NSColor
            static let name = NSAttributedString.Key.foregroundColor.rawValue
        }

        enum BackgroundColorAttribute: AttributedRopeKey {
            typealias Value = NSColor
            static let name = NSAttributedString.Key.backgroundColor.rawValue
        }

        enum UnderlineStyleAttribute: AttributedRopeKey {
            typealias Value = NSUnderlineStyle
            static let name = NSAttributedString.Key.underlineStyle.rawValue
        }

        enum UnderlineColorAttribute: AttributedRopeKey {
            typealias Value = NSColor
            static let name = NSAttributedString.Key.underlineColor.rawValue
        }
    }
}

extension AttributedRope.Attributes {
    subscript<K>(_ attribute: K.Type) -> K.Value? where K: AttributedRopeKey {
        get { contents[K.name] as? K.Value }
        set { contents[K.name] = newValue }
    }

    subscript<K>(dynamicMember keyPath: KeyPath<AttributedRope.AttributeKeys, K>) -> K.Value? where K: AttributedRopeKey {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }
}

extension AttributedRope {
    subscript<K>(_ attribute: K.Type) -> K.Value? where K: AttributedRopeKey {
        get { self[startIndex..<endIndex][K.self] }
        set { self[startIndex..<endIndex][K.self] = newValue }
    }

    subscript<K>(dynamicMember keyPath: KeyPath<AttributedRope.AttributeKeys, K>) -> K.Value? where K: AttributedRopeKey {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }
}

extension AttributedRope.Runs.Run {
    subscript<K>(_ attribute: K.Type) -> K.Value? where K: AttributedRopeKey {
        span.data[K.self]
    }

    subscript<K>(dynamicMember keyPath: KeyPath<AttributedRope.AttributeKeys, K>) -> K.Value? where K: AttributedRopeKey {
        self[K.self]
    }
}

extension AttributedSubrope {
    subscript<K>(_ attribute: K.Type) -> K.Value? where K: AttributedRopeKey {
        get {
            if bounds.isEmpty {
                return nil
            }

            let r = Range(intRangeFor: bounds)
            var first = true
            var v: K.Value?

            // TODO: Spans should be a collection and we should be able to slice and iterate through only the spans that overlap range.
            for span in spans {
                if span.range.endIndex <= r.lowerBound {
                    continue
                }

                if span.range.startIndex >= r.upperBound {
                    break
                }

                if first {
                    v = span.data[K.self]
                    first = false
                } else if span.data[K.self] != v {
                    return nil
                }
            }

            return v
        }

        set {
            if bounds.isEmpty {
                return
            }

            var b = SpansBuilder<AttributedRope.Attributes>(totalCount: text.utf8.count)
            var s = AttributedRope.Attributes()
            s[K.self] = newValue
            b.add(s, covering: Range(intRangeFor: bounds))

            spans = spans.merging(b.build()) { a, b in
                var a = a ?? AttributedRope.Attributes()
                if let b {
                    a[K.self] = b[K.self]
                }
                return a
            }

        }
    }

    subscript<K>(dynamicMember keyPath: KeyPath<AttributedRope.AttributeKeys, K>) -> K.Value? where K: AttributedRopeKey {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }
}

// MARK: - Collection

// AttributedRope is not actually a collection, but it acts like one.
extension AttributedRope {
    typealias Index = Rope.Index

    var startIndex: Index {
        text.startIndex
    }

    var endIndex: Index {
        text.endIndex
    }

    var count: Int {
        text.count
    }

    var isEmpty: Bool {
        text.isEmpty
    }

    func index(at offset: Int) -> Index {
        text.index(at: offset)
    }

    func index(beforeCharacter i: Index) -> Index {
        text.index(before: i)
    }

    func index(afterCharacter i: Index) -> Index {
        text.index(after: i)
    }

    func index(_ i: Index, offsetByCharacters distance: Int) -> Index {
        text.index(i, offsetBy: distance)
    }

    mutating func replaceSubrange<R>(_ range: R, with s: AttributedSubrope) where R: RangeExpression<Index> {
        replaceSubrange(range.relative(to: text), with: AttributedRope(s))
    }

    mutating func replaceSubrange<R>(_ range: R, with s: AttributedRope) where R: RangeExpression<Index> {
        replaceSubrange(range.relative(to: text), with: s)
    }

    mutating func replaceSubrange(_ range: Range<Index>, with s: AttributedRope) {
        if range == startIndex..<endIndex && s.isEmpty {
            text = s.text // ""
            spans = SpansBuilder<AttributedRope.Attributes>(totalCount: 0).build()
            return
        }

        if isEmpty {
            precondition(range.lowerBound == startIndex && range.upperBound == startIndex, "index out of bounds")
            text = s.text
            spans = s.spans
            return
        }

        text.replaceSubrange(range, with: s.text)

        let replacementRange = Range(intRangeFor: range)

        var sb = SpansBuilder<AttributedRope.Attributes>(totalCount: text.utf8.count)
        sb.push(spans, slicedBy: 0..<replacementRange.lowerBound)
        sb.push(s.spans)
        sb.push(spans, slicedBy: replacementRange.upperBound..<spans.upperBound)

        self.spans = sb.build()
    }

    mutating func insert(_ s: AttributedRope, at i: Index) {
        replaceSubrange(i..<i, with: s)
    }

    mutating func insert(_ s: AttributedSubrope, at i: Index) {
        replaceSubrange(i..<i, with: AttributedRope(s))
    }

    mutating func removeSubrange<R>(_ bounds: R) where R: RangeExpression<Index> {
        replaceSubrange(bounds.relative(to: text), with: AttributedRope())
    }

    mutating func append(_ s: AttributedRope) {
        replaceSubrange(endIndex..<endIndex, with: s)
    }

    mutating func append(_ s: AttributedSubrope) {
        replaceSubrange(endIndex..<endIndex, with: AttributedRope(s))
    }

    subscript(bounds: Range<AttributedRope.Index>) -> AttributedSubrope {
        _read {
            yield AttributedSubrope(text: text, spans: spans, bounds: bounds)
        }
        _modify {
            var r = AttributedSubrope(text: text, spans: spans, bounds: bounds)
            text = Rope()
            spans = SpansBuilder<Attributes>(totalCount: 0).build()

            yield &r

            text = r.text
            spans = r.spans
        }
    }
}

extension AttributedSubrope {
    var startIndex: AttributedRope.Index {
        bounds.lowerBound
    }

    var endIndex: AttributedRope.Index {
        bounds.upperBound
    }

//    subscript(bounds: Range<AttributedRope.Index>) -> AttributedSubrope {
//        _read {
//            yield AttributedSubrope(base: base, bounds: bounds)
//        }
//        _modify {
//            var r = AttributedSubrope(base: base, bounds: bounds)
//            text = Rope()
//            spans = SpansBuilder<Style>(totalCount: 0).build()
//
//            yield &r
//
//            text = r.text
//            spans = r.spans
//        }
//        set {
//            fatalError("not yet")
//            // replaceSubrange(bounds, with: newValue)
//        }
//    }
}

// MARK: - Characters

extension AttributedRope {
    struct CharacterView {
        var text: Rope
        var spans: Spans<Attributes>
    }

    var characters: CharacterView {
        _read {
            yield CharacterView(text: text, spans: spans)
        }
        _modify {
            var c = CharacterView(text: text, spans: spans)
            text = Rope()
            spans = SpansBuilder<Attributes>(totalCount: 0).build()

            yield &c

            text = c.text
            spans = c.spans
        }
    }
}

extension AttributedRope.CharacterView: BidirectionalCollection {
    typealias Index = AttributedRope.Index

    var startIndex: Index {
        text.startIndex
    }

    var endIndex: Index {
        text.endIndex
    }

    func index(after i: Index) -> Index {
        text.index(after: i)
    }

    func index(before i: Index) -> Index {
        text.index(before: i)
    }

    subscript(position: Index) -> Character {
        text[position]
    }

    // Delegate to Rope's more efficient implementations of these methods.
    func index(_ i: Index, offsetBy distance: Int) -> Index {
        text.index(i, offsetBy: distance)
    }

    func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        text.index(i, offsetBy: distance, limitedBy: limit)
    }

    func distance(from start: Index, to end: Index) -> Int {
        text.distance(from: start, to: end)
    }
}

extension AttributedRope.CharacterView: RangeReplaceableCollection {
    init() {
        self.init(text: Rope(), spans: SpansBuilder<AttributedRope.Attributes>(totalCount: 0).build())
    }
    
    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C: Collection, C.Element == Character {
        precondition(subrange.lowerBound >= startIndex && subrange.upperBound <= endIndex, "index out of bounds")

        let newElements = Rope(newElements)

        let s: AttributedRope
        if isEmpty {
            s = AttributedRope(newElements)
        } else {
            let replacementRange = Range(intRangeFor: subrange)

            let location = subrange.lowerBound == endIndex ? replacementRange.lowerBound - 1 : replacementRange.lowerBound
            var firstSpan = spans.span(at: location)!
            if replacementRange.isEmpty && replacementRange.lowerBound == firstSpan.range.lowerBound && firstSpan.range.lowerBound != 0 {
                firstSpan = spans.span(at: replacementRange.lowerBound - 1)!
            }

            s = AttributedRope(newElements, attributes: firstSpan.data)
        }

        var tmp = AttributedRope(text: text, spans: spans)

        text = Rope()
        spans = SpansBuilder<AttributedRope.Attributes>(totalCount: 0).build()

        tmp.replaceSubrange(subrange, with: s)

        text = tmp.text
        spans = tmp.spans
    }

    // The default implementation calls append(_:) in a loop.
    mutating func append<S>(contentsOf newElements: S) where S: Sequence, Self.Element == S.Element {
        replaceSubrange(endIndex..<endIndex, with: Rope(newElements))
    }
}

// MARK: - Conversion

extension AttributedRope.Attributes {
    init(_ dictionary: [NSAttributedString.Key: Any]) {
        var contents: [String: Any] = [:]

        for (key, value) in dictionary {
            contents[key.rawValue] = value
        }

        self.init(contents)
    }
}

extension AttributedRope {
    init(_ attrString: NSAttributedString) {
        let text = Rope(attrString.string)

        var b = SpansBuilder<Attributes>(totalCount: text.utf8.count)
        attrString.enumerateAttributes(in: NSRange(location: 0, length: attrString.length), options: []) { attrs, range, _ in
            b.add(Attributes(attrs), covering: Range(intRangeFor: Range(range, in: text)!))
        }

        self.text = text
        self.spans = b.build()
    }
}

extension Dictionary where Key == NSAttributedString.Key, Value == Any {
    init(_ attributes: AttributedRope.Attributes) {
        self.init()

        for (key, value) in attributes.contents {
            self[NSAttributedString.Key(key)] = value
        }
    }
}

extension NSAttributedString {
    convenience init(_ attributedRope: AttributedRope) {
        let s = NSMutableAttributedString(string: String(attributedRope.text))
        for span in attributedRope.spans {
            let attrs = Dictionary(span.data)
            let range = Range(span.range, in: attributedRope.text)
            s.addAttributes(attrs, range: NSRange(range, in: attributedRope.text))
        }
        self.init(attributedString: s)
    }
}
