//
//  TextContentManager.swift
//  Watt
//
//  Created by David Albert on 5/11/23.
//

import Cocoa

protocol TextContentManager: AnyObject {
    associatedtype Location: Comparable
    typealias TextElement = LayoutManager<Self>.TextElement

    init(_ s: String)

    var documentRange: Range<Location> { get }

    func enumerateLineRanges(from location: Location, using block: (Range<Location>) -> Bool)
    func enumerateTextElements(from location: Location, using block: (TextElement) -> Bool)

    func addLayoutManager(_ layoutManager: LayoutManager<Self>)
    func removeLayoutManager(_ layoutManager: LayoutManager<Self>)

    func attributedString(for textElement: TextElement) -> NSAttributedString

    func data(using encoding: String.Encoding) -> Data?

    // Don't love this. Come up with something better. Maybe addRenderingAttribute(_:value:for:)?
    func didSetFont(to font: NSFont)
}
