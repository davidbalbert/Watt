//
//  TextView+Appearance.swift
//  Watt
//
//  Created by David Albert on 9/11/23.
//

import Foundation

extension TextView: LayoutManagerAppearanceDelegate {
    func layoutManager(_ layoutManager: LayoutManager, attributesForTokenType type: String) -> AttributedRope.Attributes {
        resolvedTheme.attributes(forTokenType: type)
    }
}
