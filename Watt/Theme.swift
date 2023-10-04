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
    init?(xcColorThemeKey: String) {
        switch xcColorThemeKey {
            case "xcode.syntax.keyword":
                self = .keyword
            case "xcode.syntax.string":
                self = .string
            case "xcode.syntax.declaration.type":
                self = .type
            case "xcode.syntax.identifier.function":
                self = .function
            case "xcode.syntax.identifier.function.system":
                self = .functionSpecial
            case "xcode.syntax.identifier.constant":
                self = .constant
            case "xcode.syntax.identifier.variable":
                self = .variable
            case "xcode.syntax.number":
                self = .number
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
        for (key, color) in xcColorTheme.colors {
            guard let tokenType = Token.TokenType(xcColorThemeKey: key) else {
                continue
            }
            attributes[tokenType] = AttributedRope.Attributes.foregroundColor(NSColor(xcColorSchemeColor: color))
        }

        self.attributes = attributes
    }
}
