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
    var base: AttributedRope
    var bounds: Range<AttributedRope.Index>

    var font: NSFont? {
        get {
            base.spans.data(covering: Range(bounds))?.font
        }
        set {
            if bounds.isEmpty {
                return
            }

            var b = SpansBuilder<Style>(totalCount: base.text.utf8.count)
            b.add(Style(font: newValue), covering: Range(bounds))

            base.spans = base.spans.merging(b.build()) { a, b in
                var a = a ?? Style()
                a.font = b?.font
                return a
            }
        }
    }

    var foregroundColor: NSColor? {
        get {
            base.spans.data(covering: Range(bounds))?.foregroundColor
        }
        set {
            if bounds.isEmpty {
                return
            }

            var b = SpansBuilder<Style>(totalCount: base.text.utf8.count)
            b.add(Style(foregroundColor: newValue), covering: Range(bounds))

            base.spans = base.spans.merging(b.build()) { a, b in
                var a = a ?? Style()
                a.foregroundColor = b?.foregroundColor
                return a
            }
        }
    }

    var backgroundColor: NSColor? {
        get {
            base.spans.data(covering: Range(bounds))?.backgroundColor
        }
        set {
            if bounds.isEmpty {
                return
            }

            var b = SpansBuilder<Style>(totalCount: base.text.utf8.count)
            b.add(Style(backgroundColor: newValue), covering: Range(bounds))

            base.spans = base.spans.merging(b.build()) { a, b in
                var a = a ?? Style()
                a.backgroundColor = b?.backgroundColor
                return a
            }
        }
    }

    var underlineStyle: NSUnderlineStyle? {
        get {
            base.spans.data(covering: Range(bounds))?.underlineStyle
        }
        set {
            if bounds.isEmpty {
                return
            }

            var b = SpansBuilder<Style>(totalCount: base.text.utf8.count)
            b.add(Style(underlineStyle: newValue), covering: Range(bounds))

            base.spans = base.spans.merging(b.build()) { a, b in
                var a = a ?? Style()
                a.underlineStyle = b?.underlineStyle
                return a
            }
        }
    }

    var underlineColor: NSColor? {
        get {
            base.spans.data(covering: Range(bounds))?.underlineColor
        }
        set {
            if bounds.isEmpty {
                return
            }

            var b = SpansBuilder<Style>(totalCount: base.text.utf8.count)
            b.add(Style(underlineColor: newValue), covering: Range(bounds))

            base.spans = base.spans.merging(b.build()) { a, b in
                var a = a ?? Style()
                a.underlineColor = b?.underlineColor
                return a
            }
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
//            text = r.base.text
//            spans = r.base.spans
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
            yield AttributedSubrope(base: self, bounds: bounds)
        }
        _modify {
            var r = AttributedSubrope(base: self, bounds: bounds)
            text = Rope()
            spans = SpansBuilder<Style>(totalCount: 0).build()

            yield &r

            text = r.base.text
            spans = r.base.spans
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
