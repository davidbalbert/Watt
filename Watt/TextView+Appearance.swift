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
            var attributes = theme[attr.value!.type] ?? AttributedRope.Attributes()

            if attributes.font != nil {
                attributes.symbolicTraits = nil
            } else if let symbolicTraits = attributes.symbolicTraits {
                let d = font.fontDescriptor.withSymbolicTraits(symbolicTraits)
                attributes.font = NSFont(descriptor: d, size: font.pointSize) ?? font
                attributes.symbolicTraits = nil
            }

            return attr.replace(with: attributes)
        }
    }
}
