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
        var b = SpansBuilder<Attributes>(totalCount: text.utf8.count)
        if text.utf8.count > 0 {
            b.add(attributes, covering: 0..<text.utf8.count)
        }

        self.init(text: text, spans: b.build())
    }

    init(_ subrope: AttributedSubrope) {
        if Range(unvalidatedRange: subrope.bounds) == 0..<subrope.base.text.utf8.count {
            self.init(text: subrope.base.text, spans: subrope.base.spans)
            return
        }

        self.init(text: Rope(subrope.text), spans: Spans(subrope.spans))
    }

    // internal
    fileprivate init(text: Rope, spans: Spans<Attributes>) {
        assert(text.utf8.count == spans.upperBound)
        self.text = text
        self.spans = spans
    }
}

@dynamicMemberLookup
struct AttributedSubrope {
    var base: AttributedRope
    var bounds: Range<AttributedRope.Index>

    var text: Subrope {
        base.text[bounds]
    }

    var spans: SpansSlice<AttributedRope.Attributes> {
        base.spans[Range(bounds, in: base.spans)]
    }
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

        var isEmpty: Bool {
            contents.isEmpty
        }

        init() {
            contents = [:]
        }

        fileprivate init(_ contents: [String: Any]) {
            self.contents = contents
        }

        mutating func merge(_ other: Attributes, mergePolicy: AttributeMergePolicy = .keepNew) {
            contents.merge(other.contents, uniquingKeysWith: mergePolicy.combine)
        }

        func merging(_ other: Attributes, mergePolicy: AttributeMergePolicy = .keepNew) -> Attributes {
            Attributes(contents.merging(other.contents, uniquingKeysWith: mergePolicy.combine))
        }

        func merging(_ dictionary: [NSAttributedString.Key: Any], mergePolicy: AttributeMergePolicy = .keepNew) -> Attributes {
            merging(Attributes(dictionary), mergePolicy: mergePolicy)
        }
    }

    struct AttributeBuilder<T: AttributedRopeKey> {
        var attributes: Attributes

        func callAsFunction(_ value: T.Value) -> Attributes {
            var new = attributes
            new[T.self] = value
            return new
        }
    }
}

// MARK: - Runs

extension AttributedRope {
    var runs: Runs {
        Runs(base: self, bounds: startIndex..<endIndex)
    }

    struct Runs {
        var base: AttributedRope
        var bounds: Range<Index>

        private var spans: SpansSlice<AttributedRope.Attributes> {
            let start = base.spans.index(withBaseOffset: bounds.lowerBound.position)
            let end = base.spans.index(withBaseOffset: bounds.upperBound.position)

            return base.spans[start..<end]
        }

        private func spansIndex(for i: Index) -> Spans<AttributedRope.Attributes>.Index {
            i.assertValid(for: base.text)
            return spans.index(withBaseOffset: i.position - bounds.lowerBound.position)
        }

        private func index(from i: Spans<AttributedRope.Attributes>.Index) -> Index {
            i.assertValid(for: spans.base.root)
            return base.text.utf8.index(at: i.position)
        }
    }
}

extension AttributedSubrope {
    var runs: AttributedRope.Runs {
        AttributedRope.Runs(base: base, bounds: bounds)
    }
}

extension AttributedRope.Runs: BidirectionalCollection {
    typealias Index = AttributedRope.Index

    var count: Int {
        base.spans[spansIndex(for: bounds.lowerBound)..<spansIndex(for: bounds.upperBound)].count
    }

    var startIndex: Index {
        bounds.lowerBound
    }

    var endIndex: Index {
        bounds.upperBound
    }

    struct Iterator: IteratorProtocol {
        let base: AttributedRope
        var spansIter: Spans<AttributedRope.Attributes>.Iterator

        init(_ runs: AttributedRope.Runs) {
            self.base = runs.base
            spansIter = runs.spans.makeIterator()
        }

        mutating func next() -> AttributedRope.Runs.Run? {
            guard let span = spansIter.next() else {
                return nil
            }

            return AttributedRope.Runs.Run(base: base, span: span)
        }
    }

    func makeIterator() -> Iterator {
        Iterator(self)
    }

    func index(before i: Index) -> Index {
        i.validate(for: base.text)
        precondition(i.position > bounds.lowerBound.position && i.position <= bounds.upperBound.position, "Index out of bounds")

        return index(from: spans.index(before: spansIndex(for: i)))
    }

    func index(after i: Index) -> Index {
        i.validate(for: base.text)
        precondition(i.position >= bounds.lowerBound.position && i.position < bounds.upperBound.position, "Index out of bounds")

        return index(from: spans.index(after: spansIndex(for: i)))
    }

    subscript(position: Index) -> AttributedRope.Runs.Run {
        position.validate(for: base.text)
        precondition(position.position >= bounds.lowerBound.position && position.position < bounds.upperBound.position, "Index out of bounds")

        return AttributedRope.Runs.Run(base: base, span: spans[spansIndex(for: position)])
    }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        i.validate(for: base.text)
        precondition(i.position >= bounds.lowerBound.position && i.position <= bounds.upperBound.position, "Index out of bounds")

        return index(from: spans.index(spansIndex(for: i), offsetBy: distance))
    }

    func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        i.validate(for: base.text)
        precondition(i.position >= bounds.lowerBound.position && i.position <= bounds.upperBound.position, "Index out of bounds")

        guard let si = spans.index(spansIndex(for: i), offsetBy: distance, limitedBy: spansIndex(for: limit)) else {
            return nil
        }

        return index(from: si)
    }

    func distance(from start: Index, to end: Index) -> Int {
        start.validate(for: base.text)
        end.validate(for: base.text)
        precondition(start.position >= bounds.lowerBound.position && start.position <= bounds.upperBound.position, "Index out of bounds")
        precondition(end.position >= bounds.lowerBound.position && end.position <= bounds.upperBound.position, "Index out of bounds")

        return spans.distance(from: spansIndex(for: start), to: spansIndex(for: end))
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

extension AttributedRope {
    struct AttributesSlice<T> where T: AttributedRopeKey {
        var runs: AttributedRope.Runs

        var count: Int {
            var c = 0
            for run in runs {
                if run.attributes[T.self] != nil {
                    c += 1
                }
            }

            return c
        }
    }
}

extension AttributedRope.AttributesSlice: Sequence {
    func makeIterator() -> Iterator {
        Iterator(self)
    }
    
    struct Iterator: IteratorProtocol {
        var runsIter: AttributedRope.Runs.Iterator

        init(_ slice: AttributedRope.AttributesSlice<T>) {
            self.runsIter = slice.runs.makeIterator()
        }

        mutating func next() -> AttributedRope.Runs.Run? {
            while let run = runsIter.next() {
                if run.attributes[T.self] != nil {
                    return run
                }
            }

            return nil
        }
    }
}

// MARK: - Attributes

extension AttributedRope {
    struct AttributeKeys {
        // TODO: Make a macro for defining attributes that:
        // 1. Creates the enum
        // 2. Creates the property
        // 3. If it maps to an NSAttributedString.Key, add the name to knownNSAttributedStringKeys
        static var knownNSAttributedStringKeys: Set = [
            NSAttributedString.Key.font.rawValue,
            NSAttributedString.Key.foregroundColor.rawValue,
            NSAttributedString.Key.backgroundColor.rawValue,
            NSAttributedString.Key.underlineStyle.rawValue,
            NSAttributedString.Key.underlineColor.rawValue,
            NSAttributedString.Key.markedClauseSegment.rawValue,
            NSAttributedString.Key.glyphInfo.rawValue,
            NSAttributedString.Key.textAlternatives.rawValue,
            NSAttributedString.Key.attachment.rawValue,
        ]

        var font: FontAttribute
        var foregroundColor: ForegroundColorAttribute
        var backgroundColor: BackgroundColorAttribute
        var underlineStyle: UnderlineStyleAttribute
        var underlineColor: UnderlineColorAttribute
        var markedClauseSegment: MarkedClauseSegmentAttribute
        var glyphInfo: GlyphInfoAttribute
        var textAlternatives: TextAlternativesAttribute
        var attachment: AttachmentKey

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
        
        enum MarkedClauseSegmentAttribute: AttributedRopeKey {
            typealias Value = NSNumber
            static let name = NSAttributedString.Key.markedClauseSegment.rawValue
        }

        // We don't use these directly, but they're part of NSTextView's validAttributesForMarkedText
        // which we're reproducing, so we want to have them supported.
        //
        // LanguageIdentifier is missing because I don't know its type.
        enum GlyphInfoAttribute: AttributedRopeKey {
            typealias Value = NSGlyphInfo
            static let name = NSAttributedString.Key.glyphInfo.rawValue
        }

        enum TextAlternativesAttribute: AttributedRopeKey {
            typealias Value = NSTextAlternatives
            static let name = NSAttributedString.Key.textAlternatives.rawValue
        }

        enum AttachmentKey: AttributedRopeKey {
            typealias Value = NSTextAttachment
            static let name = NSAttributedString.Key.attachment.rawValue
        }


        // Watt-specific attributes

        var token: TokenAttribute
        var fontWeight: FontWeightAttribute
        var symbolicTraits: SymbolicTraitsAttribute

        // Store the whole token instead of just its type, because we want to
        // make sure that two tokens aren't merged together. Each token has a
        // unique range, which will prevent merging.
        enum TokenAttribute: AttributedRopeKey {
            typealias Value = Token
            static let name = "is.dave.Watt.Token"
        }

        enum SymbolicTraitsAttribute: AttributedRopeKey {
            typealias Value = NSFontDescriptor.SymbolicTraits
            static let name = "is.dave.Watt.SymbolicTraits"
        }

        enum FontWeightAttribute: AttributedRopeKey {
            typealias Value = NSFont.Weight
            static let name = "is.dave.Watt.FontWeight"
        }
    }
}

extension AttributedRope.Attributes {
    subscript<K>(_ attribute: K.Type) -> K.Value? where K: AttributedRopeKey {
        get {
            if let value = contents[K.name] {
                // force cast so we panic if two different attribute keys
                // have the same name but different types.
                return (value as! K.Value)
            } else {
                return nil
            }
        }
        set { contents[K.name] = newValue }
    }

    subscript<K>(dynamicMember keyPath: KeyPath<AttributedRope.AttributeKeys, K>) -> K.Value? where K: AttributedRopeKey {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }
}

extension AttributedRope.Attributes {
    static subscript<K: AttributedRopeKey>(dynamicMember keyPath: KeyPath<AttributedRope.AttributeKeys, K>) -> AttributedRope.AttributeBuilder<K> {
        return AttributedRope.AttributeBuilder(attributes: AttributedRope.Attributes())
    }

    subscript<K: AttributedRopeKey>(dynamicMember keyPath: KeyPath<AttributedRope.AttributeKeys, K>) -> AttributedRope.AttributeBuilder<K> {
        return AttributedRope.AttributeBuilder(attributes: self)
    }

    func b<K: AttributedRopeKey>() -> AttributedRope.AttributeBuilder<K> {
        return AttributedRope.AttributeBuilder(attributes: AttributedRope.Attributes())
    }
}

extension AttributedRope {
    enum AttributeMergePolicy: Equatable {
        case keepCurrent
        case keepNew

        var combine: (Any, Any) -> Any {
            switch self {
            case .keepCurrent:
                { a, b in a }
            case .keepNew:
                { a, b in b }
            }
        }
    }

    subscript<K>(_ attribute: K.Type) -> K.Value? where K: AttributedRopeKey {
        get { self[startIndex..<endIndex][K.self] }
        set { self[startIndex..<endIndex][K.self] = newValue }
    }

    subscript<K>(dynamicMember keyPath: KeyPath<AttributedRope.AttributeKeys, K>) -> K.Value? where K: AttributedRopeKey {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }

    mutating func setAttributes(_ attributes: Attributes) {
        self[...].setAttributes(attributes)
    }

    func setingAttributes(_ attributes: Attributes) -> AttributedRope {
        self[...].settingAttributes(attributes)
    }

    mutating func mergeAttributes(_ attributes: Attributes, mergePolicy: AttributeMergePolicy = .keepNew) {
        self[...].mergeAttributes(attributes, mergePolicy: mergePolicy)
    }

    func mergingAttributes(_ attributes: Attributes, mergePolicy: AttributeMergePolicy = .keepNew) -> AttributedRope {
        self[...].mergingAttributes(attributes, mergePolicy: mergePolicy)
    }
}

extension AttributedRope.Runs {
    subscript<K>(attribute: K.Type) -> AttributedRope.AttributesSlice<K> where K: AttributedRopeKey {
        AttributedRope.AttributesSlice(runs: self)
    }

    subscript<K>(keyPath: KeyPath<AttributedRope.AttributeKeys, K>) -> AttributedRope.AttributesSlice<K> where K: AttributedRopeKey {
        self[K.self]
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

            var first = true
            var v: K.Value?

            let start = base.spans.index(withBaseOffset: bounds.lowerBound.position)
            let end = base.spans.index(withBaseOffset: bounds.upperBound.position)

            for span in base.spans[start..<end] {
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

            var b = SpansBuilder<AttributedRope.Attributes>(totalCount: base.text.utf8.count)
            var s = AttributedRope.Attributes()
            s[K.self] = newValue
            b.add(s, covering: Range(unvalidatedRange: bounds))

            base.spans = base.spans.merging(b.build()) { a, b in
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

    mutating func setAttributes(_ attributes: AttributedRope.Attributes) {
        if bounds.isEmpty {
            return
        }

        let range = Range(unvalidatedRange: bounds)

        var sb = SpansBuilder<AttributedRope.Attributes>(totalCount: range.count)
        sb.add(attributes, covering: range)

        var new = sb.build()

        var dup = base.spans
        var b = BTreeBuilder<Spans<AttributedRope.Attributes>>()
        b.push(&dup.root, slicedBy: 0..<range.lowerBound)
        b.push(&new.root)
        b.push(&dup.root, slicedBy: range.upperBound..<dup.upperBound)

        base.spans = b.build()

        assert(base.spans.upperBound == base.text.utf8.count)
    }

    func settingAttributes(_ attributes: AttributedRope.Attributes) -> AttributedRope {
        var dup = self
        dup.setAttributes(attributes)
        return AttributedRope(dup)
    }

    mutating func mergeAttributes(_ attributes: AttributedRope.Attributes, mergePolicy: AttributedRope.AttributeMergePolicy = .keepNew) {
        if bounds.isEmpty {
            return
        }

        let intRange = Range(unvalidatedRange: bounds)
        let spansRange = Range(bounds, in: base.spans)

        let newSpans = Spans(base.spans[spansRange])
        let newIntRange = 0..<newSpans.upperBound

        var sb = SpansBuilder<AttributedRope.Attributes>(totalCount: newIntRange.count)
        sb.add(attributes, covering: newIntRange)

        var new = newSpans.merging(sb.build()) { a, b in
            if let a, let b {
                return a.merging(b, mergePolicy: mergePolicy)
            } else {
                return b ?? a
            }
        }

        var dup = base.spans
        var b = BTreeBuilder<Spans<AttributedRope.Attributes>>()
        b.push(&dup.root, slicedBy: 0..<intRange.lowerBound)
        b.push(&new.root)
        b.push(&dup.root, slicedBy: intRange.upperBound..<dup.upperBound)

        base.spans = b.build()

        assert(base.spans.upperBound == base.text.utf8.count)
    }

    func mergingAttributes(_ attributes: AttributedRope.Attributes, mergePolicy: AttributedRope.AttributeMergePolicy = .keepNew) -> AttributedRope {
        var dup = self
        dup.mergeAttributes(attributes, mergePolicy: mergePolicy)
        return AttributedRope(dup)
    }

    mutating func transformAttributes<K>(_ k: K.Type, _ block: (inout AttributedRope.AttributeTransformer<K>) -> Void) where K: AttributedRopeKey {
        var b = SpansBuilder<AttributedRope.Attributes>(totalCount: base.text.utf8.count)

        for run in runs {
            if run.attributes[K.self] != nil {
                var t = AttributedRope.AttributeTransformer<K>(run: run, builder: b)
                block(&t)
                b = t.builder
            }
        }

        let newSpans = base.spans.merging(b.build()) { a, b in
            guard let b else {
                return a
            }

            var a = a ?? AttributedRope.Attributes()
            a[K.self] = nil
            a.merge(b)
            return a
        }

        base.spans = newSpans
    }

    mutating func transformAttributes<K>(_ k: KeyPath<AttributedRope.AttributeKeys, K>, _ block: (inout AttributedRope.AttributeTransformer<K>) -> Void) where K: AttributedRopeKey {
        transformAttributes(K.self, block)
    }

    func transformingAttributes<K>(_ k: K.Type, _ block: (inout AttributedRope.AttributeTransformer<K>) -> Void) -> AttributedRope where K: AttributedRopeKey {
        var dup = self
        dup.transformAttributes(K.self, block)
        return AttributedRope(dup)
    }


    func transformingAttributes<K>(_ k: KeyPath<AttributedRope.AttributeKeys, K>, _ block: (inout AttributedRope.AttributeTransformer<K>) -> Void) -> AttributedRope where K: AttributedRopeKey {
        var dup = self
        dup.transformAttributes(K.self, block)
        return AttributedRope(dup)
    }
}

// MARK: - Attribute transformation

extension AttributedRope {
    struct AttributeTransformer<T> where T: AttributedRopeKey {
        let run: Runs.Run
        var builder: SpansBuilder<Attributes>

        var value: T.Value? {
            get {
                return run.attributes[T.self]
            }
            set {
                if let newValue {
                    replace(with: T.self, value: newValue)
                } else {
                    replace(with: Attributes())
                }
            }
        }

        mutating func replace(with attributes: Attributes) {
            builder.add(attributes, covering: Range(unvalidatedRange: run.range))
        }

        mutating func replace<U>(with key: U.Type, value: U.Value) where U: AttributedRopeKey {
            var attrs = Attributes()
            attrs[key] = value
            replace(with: attrs)
        }

        mutating func replace<U>(with keyPath: KeyPath<AttributeKeys, U>, value: U.Value) where U: AttributedRopeKey {
            replace(with: U.self, value: value)
        }
    }

    mutating func transformAttributes<K>(_ k: K.Type, _ block: (inout AttributedRope.AttributeTransformer<K>) -> Void) where K: AttributedRopeKey {
        self[...].transformAttributes(k, block)
    }

    mutating func transformAttributes<K>(_ k: KeyPath<AttributedRope.AttributeKeys, K>, _ block: (inout AttributedRope.AttributeTransformer<K>) -> Void) where K: AttributedRopeKey {
        self[...].transformAttributes(k, block)
    }

    func transformingAttributes<K>(_ k: K.Type, _ block: (inout AttributeTransformer<K>) -> Void) -> AttributedRope where K: AttributedRopeKey {
        self[...].transformingAttributes(k, block)
    }

    func transformingAttributes<K>(_ k: KeyPath<AttributeKeys, K>, _ block: (inout AttributeTransformer<K>) -> Void) -> AttributedRope where K: AttributedRopeKey {
        self[...].transformingAttributes(k, block)
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

    func index(_ i: Index, offsetByCharacters distance: Int, limitedBy limit: Index) -> Index? {
        text.index(i, offsetBy: distance, limitedBy: limit)
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

        let start = text.unicodeScalars.index(roundingDown: range.lowerBound)
        let end = text.unicodeScalars.index(roundingDown: range.upperBound)
        let roundedRange = start..<end

        text.replaceSubrange(roundedRange, with: s.text)

        let replacementRange = Range(unvalidatedRange: roundedRange)

        var dup = spans
        var new = s.spans

        var b = BTreeBuilder<Spans<AttributedRope.Attributes>>()
        b.push(&dup.root, slicedBy: 0..<replacementRange.lowerBound)
        b.push(&new.root)
        b.push(&dup.root, slicedBy: replacementRange.upperBound..<spans.upperBound)

        self.spans = b.build()

        assert(spans.root.count == text.root.count)
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

    subscript<R>(bounds: R) -> AttributedSubrope where R: RangeExpression<Index> {
        _read {
            let bounds = bounds.relative(to: text)
            bounds.lowerBound.validate(for: text)
            bounds.upperBound.validate(for: text)

            yield AttributedSubrope(base: self, bounds: bounds)
        }
        // TODO: it's possible to for the caller to totally replace c.base rather
        // than modifying the one we give it. We should prevent this. AttributedString
        // sets an ID and then verifies that it remians the same after the yield.
        _modify {
            let bounds = bounds.relative(to: text)
            bounds.lowerBound.validate(for: text)
            bounds.upperBound.validate(for: text)

            var r = AttributedSubrope(base: self, bounds: bounds)
            self = AttributedRope()

            yield &r

            self = r.base
        }
    }

    subscript(x: (UnboundedRange_) -> ()) -> AttributedSubrope {
        _read {
            yield self[startIndex..<endIndex]
        }
        _modify {
            yield &self[startIndex..<endIndex]
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

    subscript<R>(bounds: R) -> AttributedSubrope where R: RangeExpression<AttributedRope.Index> {
        let bounds = bounds.relative(to: base.text)
        bounds.lowerBound.validate(for: base.text)
        bounds.upperBound.validate(for: base.text)

        return AttributedSubrope(base: base, bounds: bounds)
    }
}

// MARK: - Characters

extension AttributedRope {
    struct CharacterView {
        var base: AttributedRope
        var bounds: Range<AttributedRope.Index>
    }

    var characters: CharacterView {
        _read {
            yield CharacterView(base: self, bounds: startIndex..<endIndex)
        }
        // TODO: it's possible to for the caller to totally replace c.base rather
        // than modifying the one we give it. We should prevent this. AttributedString
        // sets an ID and then verifies that it remians the same after the yield.
        _modify {
            var c = CharacterView(base: self, bounds: startIndex..<endIndex)
            self = AttributedRope()

            yield &c

            self = c.base
        }
    }
}

extension AttributedSubrope {
    var characters: AttributedRope.CharacterView {
        AttributedRope.CharacterView(base: base, bounds: bounds)
    }
}

extension AttributedRope.CharacterView: BidirectionalCollection {
    typealias Index = AttributedRope.Index

    var startIndex: Index {
        bounds.lowerBound
    }

    var endIndex: Index {
        bounds.upperBound
    }

    func index(after i: Index) -> Index {
        precondition(bounds.lowerBound <= i && i < bounds.upperBound, "out of bounds")
        return base.text.index(after: i)
    }

    func index(before i: Index) -> Index {
        precondition(bounds.lowerBound < i && i <= bounds.upperBound, "out of bounds")
        return base.text.index(before: i)
    }

    subscript(position: Index) -> Character {
        precondition(bounds.lowerBound <= position && position < bounds.upperBound, "out of bounds")
        return base.text[position]
    }

    // Delegate to Rope's more efficient implementations of these methods.
    func index(_ i: Index, offsetBy distance: Int) -> Index {
        precondition(bounds.lowerBound <= i && i <= bounds.upperBound, "out of bounds")
        let res = base.text.index(i, offsetBy: distance)
        precondition(bounds.lowerBound <= res && res <= bounds.upperBound, "out of bounds")
        return res
    }

    func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index) -> Index? {
        precondition(bounds.lowerBound <= i && i <= bounds.upperBound, "out of bounds")
        guard let res = base.text.index(i, offsetBy: distance, limitedBy: limit) else { return nil }
        precondition(bounds.lowerBound <= res && res <= bounds.upperBound, "out of bounds")
        return res
    }

    func distance(from start: Index, to end: Index) -> Int {
        precondition(bounds.lowerBound <= start && start <= bounds.upperBound)
        precondition(bounds.lowerBound <= end && end <= bounds.upperBound)
        return base.text.distance(from: start, to: end)
    }
}

extension AttributedRope.CharacterView: RangeReplaceableCollection {
    init() {
        let r = AttributedRope()
        self.init(base: r, bounds: r.startIndex..<r.endIndex)
    }
    
    mutating func replaceSubrange<C>(_ subrange: Range<Index>, with newElements: C) where C: Collection, C.Element == Character {
        precondition(subrange.lowerBound >= startIndex && subrange.upperBound <= endIndex, "index out of bounds")

        let s = AttributedRope(Rope(newElements), attributes: attributes(forReplacementRange: subrange, in: base))
        base.replaceSubrange(subrange, with: s)
    }

    // The default implementation calls append(_:) in a loop.
    mutating func append<S>(contentsOf newElements: S) where S: Sequence, Self.Element == S.Element {
        replaceSubrange(endIndex..<endIndex, with: Rope(newElements))
    }
}

fileprivate func attributes(forReplacementRange range: Range<AttributedRope.Index>, in attrRope: AttributedRope) -> AttributedRope.Attributes {
    range.lowerBound.assertValid(for: attrRope.text)
    range.upperBound.assertValid(for: attrRope.text)

    if attrRope.isEmpty {
        return AttributedRope.Attributes()
    }

    let location = range.lowerBound.position == attrRope.text.utf8.count ? attrRope.index(beforeCharacter: attrRope.endIndex) : range.lowerBound
    var run = attrRope.runs[location]
    if range.isEmpty && range.lowerBound.position == run.range.lowerBound.position && run.range.lowerBound.position != 0 {
        run = attrRope.runs[attrRope.index(beforeCharacter: range.lowerBound)]
    }

    return run.attributes
}

// MARK: - Builder

extension AttributedRope {
    struct Builder {
        var rb: RopeBuilder
        var sb: BTreeBuilder<Spans<Attributes>>

        init() {
            rb = RopeBuilder()
            sb = BTreeBuilder<Spans<Attributes>>()
        }

        mutating func push(_ r: AttributedSubrope) {
            var dup = r
            rb.push(&dup.base.text, slicedBy: r.bounds)
            sb.push(&dup.base.spans.root, slicedBy: Range(unvalidatedRange: r.bounds))
        }

        consuming func build() -> AttributedRope {
            AttributedRope(text: rb.build(), spans: sb.build())
        }
    }
}

// MARK: - Deltas

extension AttributedRope {
    struct Delta {
        var ropeDelta: BTreeDelta<Rope>
        var spansDelta: BTreeDelta<Spans<Attributes>>
    }

    struct DeltaBuilder {
        var attrRope: AttributedRope
        var rb: BTreeDeltaBuilder<Rope>
        var sb: BTreeDeltaBuilder<Spans<Attributes>>

        init(_ r: AttributedRope) {
            attrRope = r
            rb = BTreeDeltaBuilder<Rope>(attrRope.text.utf8.count)
            sb = BTreeDeltaBuilder<Spans<Attributes>>(attrRope.text.utf8.count)
        }

        mutating func removeSubrange(_ bounds: Range<Index>) {
            let r = Range(bounds, in: attrRope)

            rb.removeSubrange(r)
            sb.removeSubrange(r)
        }

        mutating func replaceSubrange(_ subrange: Range<Index>, with s: AttributedRope) {
            let start = attrRope.text.unicodeScalars.index(roundingDown: subrange.lowerBound)
            let end = attrRope.text.unicodeScalars.index(roundingDown: subrange.upperBound)

            let r = Range(start..<end, in: attrRope)

            rb.replaceSubrange(r, with: s.text)
            sb.replaceSubrange(r, with: s.spans)
        }

        mutating func replaceSubrange(_ subrange: Range<Index>, with s: String) {
            let start = attrRope.text.unicodeScalars.index(roundingDown: subrange.lowerBound)
            let end = attrRope.text.unicodeScalars.index(roundingDown: subrange.upperBound)

            let r = Range(start..<end, in: attrRope)

            let attrs = attributes(forReplacementRange: start..<end, in: attrRope)
            var b = SpansBuilder<Attributes>(totalCount: s.utf8.count)
            b.add(attrs, covering: 0..<s.utf8.count)
            let spans = b.build()

            rb.replaceSubrange(r, with: Rope(s))
            sb.replaceSubrange(r, with: spans)
        }

        consuming func build() -> Delta {
            Delta(ropeDelta: rb.build(), spansDelta: sb.build())
        }
    }

    func applying(delta: Delta) -> AttributedRope {
        let newText = text.applying(delta: delta.ropeDelta)
        let newSpans = spans.applying(delta: delta.spansDelta)

        return AttributedRope(text: newText, spans: newSpans)
    }
}

// MARK: - Debugging

extension AttributedRope: CustomStringConvertible {
    var description: String {
        var s = ""
        for run in runs {
            s += "\(String(text[run.range]))"
            s += "\(run.attributes)"
            s += "\n"
        }
        return s
    }
}

extension AttributedSubrope: CustomStringConvertible {
    var description: String {
        AttributedRope(self).description
    }
}

extension AttributedRope.Attributes: CustomStringConvertible {
    var description: String {
        var s = "{\n"
        for (key, value) in contents {
            s += "\t\(key) = \(value);\n"
        }
        s += "}"
        return s
    }
}

// MARK: - Conversion

extension AttributedRope.Attributes {
    init(_ dictionary: [NSAttributedString.Key: Any]) {
        var contents: [String: Any] = [:]

        for (key, value) in dictionary {
            if !AttributedRope.AttributeKeys.knownNSAttributedStringKeys.contains(key.rawValue) {
                print("Unknown attribute key: \(key)")
            }

            // See comment in [NSAttributedString.Key: Any].init(_ attributes:).
            if key == .underlineStyle, let value = value as? Int {
                contents[key.rawValue] = NSUnderlineStyle(rawValue: value)
            } else {
                contents[key.rawValue] = value
            }
        }

        self.init(contents)
    }
}

extension AttributedRope {
    init(_ attrString: NSAttributedString, merging attributes: AttributedRope.Attributes = .init()) {
        let text = Rope(attrString.string)

        var b = SpansBuilder<Attributes>(totalCount: text.utf8.count)
        attrString.enumerateAttributes(in: NSRange(location: 0, length: attrString.length), options: []) { attrs, range, _ in
            b.add(Attributes(attrs).merging(attributes), covering: Range(unvalidatedRange: Range(range, in: text)!))
        }

        self.text = text
        self.spans = b.build()
    }
}

extension String {
    init(_ attributedSubrope: AttributedSubrope) {
        self.init(attributedSubrope.base.text[attributedSubrope.startIndex..<attributedSubrope.endIndex])
    }
}

extension Dictionary where Key == NSAttributedString.Key, Value == Any {
    init(_ attributes: AttributedRope.Attributes) {
        self.init()

        for (key, value) in attributes.contents {
            let k = NSAttributedString.Key(key)

            // NSAttributedString requires underline style to be specified
            // as an NSNumber, not an NSUnderlineStyle, but we want
            // .underlineStyle to be an NSUnderlineStyle, so we transform
            // it here.
            //
            // This is definitely a hack, but it's easy. If we find more
            // keys like this, we should consider a more general solution.
            // If that comes up, take a look at ObjectiveCConvertibleAttributedStringKey
            // in swift-corelibs-foundation, which is solving the same
            // problem. We can't implement attributeKeyType(matching key: String)
            // because _forEachField(of:, options:) isn't public, but we could
            // find another way to recover the AttributedRopeKey for a given
            // String in Attributes.contents.
            if k == .underlineStyle, let value = value as? NSUnderlineStyle {
                self[k] = value.rawValue
            } else {
                self[k] = value
            }
        }
    }
}

extension NSAttributedString {
    convenience init(_ attributedRope: AttributedRope) {
        // Creating CFAttributedStrings seems somewhat faster than
        // creating NSAttributedStrings directly.
        self.init(attributedString: attributedRope.cfAttributedString)
    }

    convenience init(_ attributedSubrope: AttributedSubrope) {
        self.init(attributedString: attributedSubrope.cfAttributedString)
    }
}

extension AttributedRope {
    var cfAttributedString: CFAttributedString {
        self[...].cfAttributedString
    }
}

extension AttributedSubrope {
    var cfAttributedString: CFAttributedString {
        let u16len = text.utf16.count
        let attrStr = CFAttributedStringCreateMutable(kCFAllocatorDefault, u16len)!

        CFAttributedStringBeginEditing(attrStr)
        CFAttributedStringReplaceString(
            attrStr,
            CFRange(location: 0, length: 0),
            String(text) as CFString
        )

        for run in runs {
            let attrs = Dictionary(run.attributes) as CFDictionary
            let range = CFRange(unvalidatedRange: run.range, in: text)
            CFAttributedStringSetAttributes(
                attrStr,
                range,
                attrs,
                false
            )
        }

        CFAttributedStringEndEditing(attrStr)

        return attrStr
    }
}

extension Range where Bound == AttributedRope.Index {
    init(_ range: Range<Int>, in attributedRope: AttributedRope) {
        self.init(range, in: attributedRope.text)
    }
}

extension Range where Bound == Int {
    init(_ range: Range<AttributedRope.Index>, in attributedRope: AttributedRope) {
        self.init(range, in: attributedRope.text)
    }
}

extension Range where Bound == Spans<AttributedRope.Attributes>.Index {
    init(_ range: Range<AttributedRope.Index>, in spans: Spans<AttributedRope.Attributes>) {
        let start = spans.index(withBaseOffset: range.lowerBound.position)
        let end = spans.index(withBaseOffset: range.upperBound.position)
        self = start..<end
    }
}
