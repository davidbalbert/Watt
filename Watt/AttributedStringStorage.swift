//
//  AttributedStringStorage.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

final class AttributedStringStorage: ExpressibleByStringLiteral {
    var s: AttributedString
    var layoutManagers: [LayoutManager<AttributedStringStorage>] = []

    init() {
        self.s = ""
    }

    init(_ s: AttributedString) {
        self.s = s
    }

    init(_ s: String) {
        self.s = AttributedString(s)
    }

    required init(stringLiteral stringValue: String) {
        self.s = AttributedString(stringValue)
    }

    var string: String {
        String(s.characters[...])
    }
}


extension AttributedStringStorage: TextStorage {
    typealias Index = AttributedString.Index

    func addLayoutManager(_ layoutManager: LayoutManager<AttributedStringStorage>) {
        layoutManagers.append(layoutManager)
        layoutManager.storage = self
    }

    func removeLayoutManager(_ layoutManager: LayoutManager<AttributedStringStorage>) {
        var indices: [Int] = []
        for (i, m) in layoutManagers.enumerated() {
            if m === layoutManager {
                indices.append(i)
            }
        }

        for i in indices {
            let m = layoutManagers.remove(at: i)
            m.storage = nil
        }
    }

    var documentRange: Range<AttributedString.Index> {
        s.startIndex..<s.endIndex
    }

    func textElements(for range: Range<AttributedString.Index>) -> [TextElement] {
        []
    }
}
