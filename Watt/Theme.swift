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
        case invalid
    }

    let attributes: [Token.TokenType: AttributedRope.Attributes]

    static let defaultTheme: Theme = try! Theme(name: "Default (Light)", withExtension: "xccolortheme")

    init(name: String, withExtension ext: String) throws {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Themes") else {
            throw ThemeError.notFound
        }

        switch ext {
            case "xccolortheme":
                try self.init(contentsOfXCColorThemeURL: url)
            default:
                throw ThemeError.invalid
        }
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

struct XCColorTheme: Decodable {
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

    // load the colors from the DVTSourceTextSyntaxColors key
    let colors: [String: Color]

    enum CodingKeys: String, CodingKey {
        case colors = "DVTSourceTextSyntaxColors"
    }
}

extension Token.TokenType {
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

extension NSColor {
    convenience init(xcColorSchemeColor color: XCColorTheme.Color) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}

extension Theme {
    // initialize a theme from an Xcode theme file URL
    init(contentsOfXCColorThemeURL url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = PropertyListDecoder()
        let xcColorTheme = try decoder.decode(XCColorTheme.self, from: data)

        var attributes: [Token.TokenType: AttributedRope.Attributes] = [:]

        for t in Token.TokenType.allCases {
            guard let key = t.xcColorThemeKey else {
                continue
            }

            guard let color = xcColorTheme.colors[key] else {
                continue
            }

            let foregroundColor = NSColor(xcColorSchemeColor: color)
            let attrs = AttributedRope.Attributes.foregroundColor(foregroundColor)
            attributes[t] = attrs
        }

        self.attributes = attributes
    }
}
