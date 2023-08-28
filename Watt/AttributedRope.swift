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
            spans.data(covering: 0..<spans.count)?.font
        }
        set {
            if text.isEmpty {
                return
            }

            var b = SpansBuilder<Style>(totalCount: text.utf8.count)
            b.add(Style(font: newValue), covering: 0..<text.utf8.count)

            spans = spans.merging(b.build()) { a, b in
                var a = a ?? Style()
                a.font = b!.font
                return a
            }
        }
    }

    var foregroundColor: NSColor? {
        get {
            spans.data(covering: 0..<spans.count)?.foregroundColor
        }
        set {
            if text.isEmpty {
                return
            }

            var b = SpansBuilder<Style>(totalCount: text.utf8.count)
            b.add(Style(foregroundColor: newValue), covering: 0..<text.utf8.count)

            spans = spans.merging(b.build()) { a, b in
                var a = a ?? Style()
                a.foregroundColor = b!.foregroundColor
                return a
            }
        }
    }

    var backgroundColor: NSColor? {
        get {
            spans.data(covering: 0..<spans.count)?.backgroundColor
        }
        set {
            if text.isEmpty {
                return
            }

            var b = SpansBuilder<Style>(totalCount: text.utf8.count)
            b.add(Style(backgroundColor: newValue), covering: 0..<text.utf8.count)

            spans = spans.merging(b.build()) { a, b in
                var a = a ?? Style()
                a.backgroundColor = b!.backgroundColor
                return a
            }
        }
    }

    var underlineStyle: NSUnderlineStyle? {
        get {
            spans.data(covering: 0..<spans.count)?.underlineStyle
        }
        set {
            if text.isEmpty {
                return
            }

            var b = SpansBuilder<Style>(totalCount: text.utf8.count)
            b.add(Style(underlineStyle: newValue), covering: 0..<text.utf8.count)

            spans = spans.merging(b.build()) { a, b in
                var a = a ?? Style()
                a.underlineStyle = b!.underlineStyle
                return a
            }
        }
    }

    var underlineColor: NSColor? {
        get {
            spans.data(covering: 0..<spans.count)?.underlineColor
        }
        set {
            if text.isEmpty {
                return
            }

            var b = SpansBuilder<Style>(totalCount: text.utf8.count)
            b.add(Style(underlineColor: newValue), covering: 0..<text.utf8.count)

            spans = spans.merging(b.build()) { a, b in
                var a = a ?? Style()
                a.underlineColor = b!.underlineColor
                return a
            }
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
