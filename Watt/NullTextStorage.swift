//
//  NullTextStorage.swift
//  Watt
//
//  Created by David Albert on 4/30/23.
//

import Foundation

struct NullTextLocation: TextLocation {
    func compare(_ location: TextLocation) -> ComparisonResult {
        return .orderedSame
    }
}

struct NullTextRange: TextRange {
    var start: TextLocation {
        NullTextLocation()
    }

    var end: TextLocation {
        NullTextLocation()
    }

    var isEmpty: Bool {
        true
    }
}

class NullTextStorage: TextStorage {
    var documentRange: TextRange {
        NullTextRange()
    }

    func enumerateTextElements(from textLocation: TextLocation, using block: (TextElement) -> Bool) {
    }

    func addLayoutManager(_ layoutManager: LayoutManager) {
    }

    func removeLayoutManager(_ layoutManager: LayoutManager) {
    }
}
