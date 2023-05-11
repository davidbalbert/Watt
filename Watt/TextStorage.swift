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
    func attributedString(for textElement: TextElement) -> NSAttributedString

    func addLayoutManager(_ layoutManager: LayoutManager)
    func removeLayoutManager(_ layoutManager: LayoutManager)
}

extension TextStorage {
    func firstTextElement(in range: TextRange) -> TextElement? {
        var element: TextElement? = nil

        enumerateTextElements(from: range.start) { el in
            element = el
            return false
        }

        return element
    }

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
