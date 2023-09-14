//
//  TextView+Appearance.swift
//  Watt
//
//  Created by David Albert on 9/11/23.
//

import Cocoa

extension TextView: LayoutManagerAppearanceDelegate {
    func defaultFont(for layoutManager: LayoutManager) -> NSFont {
        font
    }
    
    func layoutManager(_ layoutManager: LayoutManager, attributesForTokenType type: Token.TokenType) -> AttributedRope.Attributes? {
        theme[type]
    }
}
