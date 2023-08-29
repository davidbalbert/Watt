//
//  BigAttributedString.swift
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
    var spans: Spans<AttributedRope.AttributeContainer>

    init(_ string: String) {
        self.init(Rope(string))
    }

    init(_ text: Rope) {
        self.text = text

        var b = SpansBuilder<AttributedRope.AttributeContainer>(totalCount: text.utf8.count)
        if text.utf8.count > 0 {
            b.add(AttributeContainer(), covering: 0..<text.utf8.count)
        }
        self.spans = b.build()
    }
}

@dynamicMemberLookup
struct AttributedSubrope {
    var text: Rope
    var spans: Spans<AttributedRope.AttributeContainer>
    var bounds: Range<AttributedRope.Index>
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
        var span: Span<AttributedRope.AttributeContainer>

        var range: Range<AttributedRope.Index> {
            Range(span.range, in: base.text)
        }
    }
}

extension AttributedRope.Runs: Sequence {
    struct Iterator: IteratorProtocol {
        var i: Spans<AttributedRope.AttributeContainer>.Iterator
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
    struct Attributes {
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

extension AttributedRope {
    @dynamicMemberLookup
    struct AttributeContainer: Equatable {
        static func == (lhs: AttributedRope.AttributeContainer, rhs: AttributedRope.AttributeContainer) -> Bool {
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

        init() {
            contents = [:]
        }

        subscript<K>(_ attribute: K.Type) -> K.Value? where K: AttributedRopeKey {
            get { contents[K.name] as? K.Value }
            set { contents[K.name] = newValue }
        }

        subscript<K>(dynamicMember keyPath: KeyPath<AttributedRope.Attributes, K>) -> K.Value? where K: AttributedRopeKey {
            get { self[K.self] }
            set { self[K.self] = newValue }
        }
    }
}

extension AttributedRope {
    subscript<K>(_ attribute: K.Type) -> K.Value? where K: AttributedRopeKey {
        get { self[startIndex..<endIndex][K.self] }
        set { self[startIndex..<endIndex][K.self] = newValue }
    }

    subscript<K>(dynamicMember keyPath: KeyPath<AttributedRope.Attributes, K>) -> K.Value? where K: AttributedRopeKey {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }
}

extension AttributedRope.Runs.Run {
    subscript<K>(_ attribute: K.Type) -> K.Value? where K: AttributedRopeKey {
        span.data[K.self]
    }

    subscript<K>(dynamicMember keyPath: KeyPath<AttributedRope.Attributes, K>) -> K.Value? where K: AttributedRopeKey {
        self[K.self]
    }
}

extension AttributedSubrope {
    subscript<K>(_ attribute: K.Type) -> K.Value? where K: AttributedRopeKey {
        get {
            if bounds.isEmpty {
                return nil
            }

            let r = Range(bounds)
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

            var b = SpansBuilder<AttributedRope.AttributeContainer>(totalCount: text.utf8.count)
            var s = AttributedRope.AttributeContainer()
            s[K.self] = newValue
            b.add(s, covering: Range(bounds))

            spans = spans.merging(b.build()) { a, b in
                var a = a ?? AttributedRope.AttributeContainer()
                if let b {
                    a[K.self] = b[K.self]
                }
                return a
            }

        }
    }

    subscript<K>(dynamicMember keyPath: KeyPath<AttributedRope.Attributes, K>) -> K.Value? where K: AttributedRopeKey {
        get { self[K.self] }
        set { self[K.self] = newValue }
    }
}

// MARK: - Collection

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

extension AttributedRope {
    typealias Index = Rope.Index

    var startIndex: Index {
        text.startIndex
    }

    var endIndex: Index {
        text.endIndex
    }

    var isEmpty: Bool {
        text.isEmpty
    }

    func index(at: Int) -> Index {
        text.index(at: at)
    }

    subscript(bounds: Range<AttributedRope.Index>) -> AttributedSubrope {
        _read {
            yield AttributedSubrope(text: text, spans: spans, bounds: bounds)
        }
        _modify {
            var r = AttributedSubrope(text: text, spans: spans, bounds: bounds)
            text = Rope()
            spans = SpansBuilder<AttributedRope.AttributeContainer>(totalCount: 0).build()

            yield &r

            text = r.text
            spans = r.spans
        }
    }
}

extension Dictionary where Key == NSAttributedString.Key, Value == Any {
    init(_ attributes: AttributedRope.AttributeContainer) {
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

fileprivate func isEqual(_ a: Any?, _ b: Any?) -> Bool {
    switch (a, b) {
    case (.none, .none):
        return true
    case (.none, .some(_)):
        return false
    case (.some(_), .none):
        return false
    case let (.some(a), .some(b)):
        func helper<E: Equatable>(_ a: E) -> Bool {
            if let b = b as? E {
                return a == b
            } else {
                return false
            }
        }

        if let a = a as? any Equatable {
            return helper(a)
        }

        return false
    }
}
