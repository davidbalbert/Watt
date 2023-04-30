//
//  LayoutFragment.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

struct LayoutFragment {
    struct EnumerationOptions: OptionSet {
        let rawValue: Int

        static let ensuresLayout = EnumerationOptions(rawValue: 1 << 0)
    }

    var textRange: TextRange
}
