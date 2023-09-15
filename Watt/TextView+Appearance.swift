//
//  TextView+Appearance.swift
//  Watt
//
//  Created by David Albert on 9/11/23.
//

import Cocoa

extension TextView: LayoutManagerAppearanceDelegate {
    func layoutManager(_ layoutManager: LayoutManager, applyStylesTo attrRope: AttributedRope) -> AttributedRope {
        return attrRope.transformingAttributes(\.token) { attr in
            let attributes = theme[attr.value!.type] ?? AttributedRope.Attributes()
            return attr.replace(with: attributes)
        }
    }
}
