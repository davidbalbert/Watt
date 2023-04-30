//
//  TextStorage.swift
//  Watt
//
//  Created by David Albert on 4/30/23.
//

import Foundation

protocol TextStorage: AnyObject {
    var documentRange: TextRange { get }
    func enumerateTextElements(from textLocation: TextLocation, using block: (TextElement) -> Bool)
    func addLayoutManager(_ layoutManager: LayoutManager)
    func removeLayoutManager(_ layoutManager: LayoutManager)
}

extension TextStorage {
    func textElements(for range: TextRange) -> [TextElement] {
        var res: [TextElement] = []

        enumerateTextElements(from: range.start) { element in
            if range.end.compare(element.textRange.start) == .orderedAscending {
                return false
            }

            res.append(element)
            return true
        }

        return res
    }
}
