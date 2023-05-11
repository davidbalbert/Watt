//
//  TextStorage.swift
//  Watt
//
//  Created by David Albert on 5/11/23.
//

import Foundation

protocol TextStorage: AnyObject {
    associatedtype Location: Comparable

    init<S>(_ s: S) where S: StringProtocol

    var documentRange: Range<Location> { get }
    func enumerateTextElements(from location: Location, using block: (TextElement<Self>) -> Bool)

    func addLayoutManager(_ layoutManager: LayoutManager<Self>)
    func removeLayoutManager(_ layoutManager: LayoutManager<Self>)

    func attributedString(for textElement: TextElement<Self>) -> NSAttributedString
}

extension TextStorage {
    func textElements(for range: Range<Location>) -> [TextElement<Self>] {
        var res: [TextElement<Self>] = []

        enumerateTextElements(from: range.lowerBound) { element in
            if element.textRange.lowerBound >= range.upperBound {
                return false
            }

            res.append(element)
            return true
        }

        return res
    }
}
