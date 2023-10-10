//
//  Theme.swift
//  Watt
//
//  Created by David Albert on 9/11/23.
//

import Cocoa

struct Theme {
    enum ThemeError: Error {
        case notFound
        case invalidFormat
        case cannotParse
        case noMainFont
        case noForegroundColor
        case noLineNumberColor
    }

    var foregroundColor: NSColor
    var backgroundColor: NSColor
    var insertionPointColor: NSColor
    var selectedTextBackgroundColor: NSColor
    var lineNumberColor: NSColor
    var markedTextAttributes: AttributedRope.Attributes
    var attributes: [Token.TokenType: AttributedRope.Attributes]

    // A theme that uses system colors and reacts to
    // changes in the system appearance.
    static let system: Theme = Theme(
        foregroundColor: .textColor,
        backgroundColor: .textBackgroundColor,
        // TODO: .textInsertionPointColor on Sonoma.
        insertionPointColor: .textColor,
        selectedTextBackgroundColor: .selectedTextBackgroundColor,
        lineNumberColor: .secondaryLabelColor,
        markedTextAttributes: AttributedRope.Attributes.backgroundColor(.systemYellow.withSystemEffect(.disabled))
    )

    init(name: String, withExtension ext: String) throws {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Themes") else {
            throw ThemeError.notFound
        }

        switch ext {
            case "xccolortheme":
                try self.init(contentsOfXCColorThemeURL: url)
            default:
                throw ThemeError.invalidFormat
        }
    }

    init(foregroundColor: NSColor, backgroundColor: NSColor, insertionPointColor: NSColor, selectedTextBackgroundColor: NSColor, lineNumberColor: NSColor, markedTextAttributes: AttributedRope.Attributes, attributes: [Token.TokenType: AttributedRope.Attributes] = [:]) {
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.insertionPointColor = insertionPointColor
        self.selectedTextBackgroundColor = selectedTextBackgroundColor
        self.lineNumberColor = lineNumberColor
        self.markedTextAttributes = markedTextAttributes
        self.attributes = attributes
    }

    subscript(key: Token.TokenType) -> AttributedRope.Attributes? {
        var type: Token.TokenType? = key

        while let t = type {
            if let attrs = attributes[t] {
                return attrs
            }

            if let i = t.rawValue.lastIndex(of: ".") {
                let parent = t.rawValue[..<i]
                type = Token.TokenType(rawValue: String(parent))
            } else {
                type = nil
            }
        }

        return nil
    }
}

fileprivate struct XCColorTheme: Decodable {
    struct Color: Decodable {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let components = string.split(separator: " ").compactMap { Double($0) }
            guard components.count == 4 else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid color string")
            }
            self.red = CGFloat(components[0])
            self.green = CGFloat(components[1])
            self.blue = CGFloat(components[2])
            self.alpha = CGFloat(components[3])
        }
    }

    struct Font: Decodable {
        enum FontError: Error {
            case cannotParse
            case unknownVariant
        }

        let name: String
        let weight: NSFont.Weight
        let symbolicTraits: NSFontDescriptor.SymbolicTraits
        let size: CGFloat

        // SFMono-Regular - 12.0 -> ("SFMono", .bold, [], 12.0)
        // HelveticaNeue - 12.0 -> ("HelveticaNeue", .regular, [], 12.0) 
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let components = string.split(separator: " - ")
            guard components.count == 2 else {
                throw FontError.cannotParse
            }

            // split name and optional variant
            let nameAndVariant = components[0].split(separator: "-")
            guard nameAndVariant.count == 1 || nameAndVariant.count == 2 else {
                throw FontError.cannotParse
            }

            self.name = String(nameAndVariant[0])

            if nameAndVariant.count == 2 {
                let variant = String(nameAndVariant[1])
                switch variant {
                case "Regular":
                    self.weight = .regular
                    self.symbolicTraits = []
                case "Bold":
                    self.weight = .bold
                    self.symbolicTraits = []
                case "Italic":
                    self.weight = .regular
                    self.symbolicTraits = .italic
                case "Semibold":
                    self.weight = .semibold
                    self.symbolicTraits = []
                case "Medium":
                    self.weight = .medium
                    self.symbolicTraits = []
                default:
                    throw FontError.unknownVariant
                }
            } else {
                self.weight = .regular
                self.symbolicTraits = []
            }

            guard let size = Double(components[1]) else {
                throw FontError.cannotParse
            }

            self.size = size
        }
    }

    enum CodingKeys: String, CodingKey {
        case backgroundColor = "DVTSourceTextBackground"
        case textSelectionColor = "DVTConsoleTextSelectionColor"
        case colors = "DVTSourceTextSyntaxColors"
        case fonts = "DVTSourceTextSyntaxFonts"
    }

    let textSelectionColor: Color
    let backgroundColor: Color
    let colors: [String: Color]
    let fonts: [String: Font]
}

fileprivate extension NSFont {
    convenience init?(xcFont font: XCColorTheme.Font) {
        let traits: [NSFontDescriptor.TraitKey: Any] = [
            .weight: font.weight,
            .symbolic: font.symbolicTraits
        ]

        let descriptor = NSFontDescriptor(fontAttributes: [
            .name: font.name,
            .traits: traits,
        ])

        self.init(descriptor: descriptor, size: font.size)
    }
}

fileprivate extension Token.TokenType {
    var xcColorThemeKey: String? {
        switch self {
            case .keyword:
                return "xcode.syntax.keyword"
            case .string:
                return "xcode.syntax.string"
            case .type:
                return "xcode.syntax.declaration.type"
            case .function:
                return "xcode.syntax.identifier.function"
            case .functionSpecial:
                return "xcode.syntax.identifier.macro"
            case .constant:
                return "xcode.syntax.identifier.constant"
            case .variable, .property:
                return "xcode.syntax.identifier.variable"
            case .number:
                return "xcode.syntax.number"
            case .comment:
                return "xcode.syntax.comment"
            default:
                return nil
        }
    }
}

fileprivate extension NSColor {
    convenience init(xcColor color: XCColorTheme.Color) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}

extension Theme {
    // initialize a theme from an Xcode theme file URL
    init(contentsOfXCColorThemeURL url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = PropertyListDecoder()
        let xcColorTheme = try decoder.decode(XCColorTheme.self, from: data)

        guard let mainFont = xcColorTheme.fonts["xcode.syntax.plain"] else {
            throw ThemeError.noMainFont
        }

        guard let foregroundColor = xcColorTheme.colors["xcode.syntax.plain"] else {
            throw ThemeError.noForegroundColor
        }

        var attributes: [Token.TokenType: AttributedRope.Attributes] = [:]

        for t in Token.TokenType.allCases {
            guard let key = t.xcColorThemeKey else {
                continue
            }

            var attrs: AttributedRope.Attributes = AttributedRope.Attributes()

            if let font = xcColorTheme.fonts[key] {
                if font.name != mainFont.name {
                    attrs.font = NSFont(xcFont: font)
                } else {
                    attrs.fontWeight = font.weight

                    if font.symbolicTraits != [] {
                        attrs.symbolicTraits = font.symbolicTraits
                    }
                }
            }

            if let color = xcColorTheme.colors[key] {
                attrs.foregroundColor = NSColor(xcColor: color)
            }

            if !attrs.isEmpty {
                attributes[t] = attrs
            }
        }

        let backgroundColor = NSColor(xcColor: xcColorTheme.backgroundColor)
        let insertionPointColor: NSColor
        if backgroundColor.brightnessComponent < 0.5 {
            insertionPointColor = .white
        } else {
            insertionPointColor = .black
        }

        guard let lineNumberColor = xcColorTheme.colors["xcode.syntax.comment"] else {
            throw ThemeError.noLineNumberColor
        }

        self.foregroundColor = NSColor(xcColor: foregroundColor)
        self.backgroundColor = backgroundColor
        self.insertionPointColor = insertionPointColor
        self.selectedTextBackgroundColor = NSColor(xcColor: xcColorTheme.textSelectionColor)
        self.lineNumberColor = NSColor(xcColor: lineNumberColor)
        self.markedTextAttributes = AttributedRope.Attributes.underlineStyle(.single)
        self.attributes = attributes
    }
}
