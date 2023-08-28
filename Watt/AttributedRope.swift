//
//  BigAttributedString.swift
//  Watt
//
//  Created by David Albert on 8/27/23.
//

import AppKit

struct Style {
    static let knownAttributes: Set<NSAttributedString.Key> = [.font, .underlineStyle, .foregroundColor, .backgroundColor, .underlineColor]

    var font: NSFont?
    var foregroundColor: NSColor?
    var backgroundColor: NSColor?
    var underlineStyle: NSUnderlineStyle?
    var underlineColor: NSColor?

    init(font: NSFont? = nil, foregroundColor: NSColor? = nil, backgroundColor: NSColor? = nil, underlineStyle: NSUnderlineStyle? = nil, underlineColor: NSColor? = nil) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.underlineStyle = underlineStyle
        self.underlineColor = underlineColor
    }

    init(_ attributes: [NSAttributedString.Key: Any]) {
        for k in attributes.keys {
            if !Style.knownAttributes.contains(k) {
                print("Style: unknown NSAttributedString.Key: \(k)")
            }
        }

        self.font = attributes[.font] as? NSFont
        self.foregroundColor = attributes[.foregroundColor] as? NSColor
        self.backgroundColor = attributes[.backgroundColor] as? NSColor
        self.underlineStyle = attributes[.underlineStyle] as? NSUnderlineStyle
        self.underlineColor = attributes[.underlineColor] as? NSColor
    }

    var attributes: [NSAttributedString.Key: Any] {
        var a: [NSAttributedString.Key: Any] = [:]

        if let font { a[.font] = font }
        if let foregroundColor { a[.foregroundColor] = foregroundColor }
        if let backgroundColor { a[.backgroundColor] = backgroundColor }
        if let underlineStyle { a[.underlineStyle] = underlineStyle }
        if let underlineColor { a[.underlineColor] = underlineColor }
        return a
    }
}

struct AttributedRope {
    var text: Rope
    var spans: Spans<Style>

    init(_ string: String) {
        self.init(Rope(string))
    }

    init(_ text: Rope) {
        self.text = text

        var b = SpansBuilder<Style>(totalCount: text.utf8.count)
        if text.utf8.count > 0 {
            b.add(Style(), covering: 0..<text.utf8.count)
        }
        self.spans = b.build()
    }
}

// MARK: - Attributes

extension AttributedRope {
    var font: NSFont? {
        get {
            self[startIndex..<endIndex].font
        }
        set {
            self[startIndex..<endIndex].font = newValue
        }
    }

    var foregroundColor: NSColor? {
        get {
            self[startIndex..<endIndex].foregroundColor
        }
        set {
            self[startIndex..<endIndex].foregroundColor = newValue
        }
    }

    var backgroundColor: NSColor? {
        get {
            self[startIndex..<endIndex].backgroundColor
        }
        set {
            self[startIndex..<endIndex].backgroundColor = newValue
        }
    }

    var underlineStyle: NSUnderlineStyle? {
        get {
            self[startIndex..<endIndex].underlineStyle
        }
        set {
            self[startIndex..<endIndex].underlineStyle = newValue
        }
    }

    var underlineColor: NSColor? {
        get {
            self[startIndex..<endIndex].underlineColor
        }
        set {
            self[startIndex..<endIndex].underlineColor = newValue
        }
    }
}

// MARK: - Collection

struct AttributedSubrope {
    var text: Rope
    var spans: Spans<Style>
    var bounds: Range<AttributedRope.Index>

    func value<Value>(forKey key: KeyPath<Style, Value?>) -> Value? where Value: Equatable {
        let r = Range(bounds)
        var first = true
        var v: Value?

        // TODO: Spans should be a collection and we should be able to slice and iterate through only the spans that overlap range.
        for span in spans {
            if span.range.endIndex <= r.lowerBound {
                continue
            }

            if span.range.startIndex >= r.upperBound {
                break
            }

            if first {
                v = span.data[keyPath: key]
                first = false
            } else if span.data[keyPath: key] != v {
                return nil
            }
        }

        return v
    }

    mutating func setValue<Value>(_ value: Value?, forKey key: WritableKeyPath<Style, Value?>) where Value: Equatable {
        if bounds.isEmpty {
            return
        }

        var b = SpansBuilder<Style>(totalCount: text.utf8.count)
        var s = Style()
        s[keyPath: key] = value
        b.add(s, covering: Range(bounds))

        spans = spans.merging(b.build()) { a, b in
            var a = a ?? Style()
            a[keyPath: key] = b?[keyPath: key]
            return a
        }
    }

    var font: NSFont? {
        get {
            value(forKey: \.font)
        }
        set {
            setValue(newValue, forKey: \.font)
        }
    }

    var foregroundColor: NSColor? {
        get {
            value(forKey: \.foregroundColor)
        }
        set {
            setValue(newValue, forKey: \.foregroundColor)
        }
    }

    var backgroundColor: NSColor? {
        get {
            value(forKey: \.backgroundColor)
        }
        set {
            setValue(newValue, forKey: \.backgroundColor)
        }
    }

    var underlineStyle: NSUnderlineStyle? {
        get {
            value(forKey: \.underlineStyle)
        }
        set {
            setValue(newValue, forKey: \.underlineStyle)
        }
    }

    var underlineColor: NSColor? {
        get {
            value(forKey: \.underlineColor)
        }
        set {
            setValue(newValue, forKey: \.underlineColor)
        }
    }

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
            spans = SpansBuilder<Style>(totalCount: 0).build()

            yield &r

            text = r.text
            spans = r.spans
        }
    }
}

// MARK: - Runs

extension AttributedRope {
    struct Runs {
        var base: AttributedRope

        var count: Int {
            base.spans.spanCount
        }
    }

    var runs: Runs {
        Runs(base: self)
    }
}

extension NSAttributedString {
    convenience init(_ attributedRope: AttributedRope) {
        let s = NSMutableAttributedString(string: String(attributedRope.text))
        for span in attributedRope.spans {
            let attrs = span.data.attributes
            let range = Range(span.range, in: attributedRope.text)
            s.addAttributes(attrs, range: NSRange(range, in: attributedRope.text))
        }
        self.init(attributedString: s)
    }
}
