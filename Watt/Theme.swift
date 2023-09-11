//
//  Theme.swift
//  Watt
//
//  Created by David Albert on 9/11/23.
//

import Cocoa

struct Theme {
    func resolved(with font: NSFont) -> ResolvedTheme {
        ResolvedTheme()
    }
}

struct ResolvedTheme {
    var attributes: [String: AttributedRope.Attributes]

    init() {
        self.attributes = [:]
    }

    func attributes(forTokenType type: String) -> AttributedRope.Attributes {
        attributes[type] ?? AttributedRope.Attributes()
    }
}
