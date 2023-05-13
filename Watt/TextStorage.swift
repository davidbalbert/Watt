//
//  TextStorage.swift
//  Watt
//
//  Created by David Albert on 5/11/23.
//

import Foundation

protocol TextStorage: AnyObject {
    associatedtype Location: Comparable
    typealias TextElement = LayoutManager<Self>.TextElement

    init<S>(_ s: S) where S: StringProtocol

    var documentRange: Range<Location> { get }
    
    func enumerateTextElements(from location: Location, using block: (TextElement) -> Bool)
    func enumerateLineRanges(from location: Location, using block: (Range<Location>) -> Bool)

    func addLayoutManager(_ layoutManager: LayoutManager<Self>)
    func removeLayoutManager(_ layoutManager: LayoutManager<Self>)

    func attributedString(for textElement: TextElement) -> NSAttributedString
}
