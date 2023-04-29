//
//  TextStorage.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

protocol TextStorage: AnyObject {
//    associatedtype Index: Comparable
//    associatedtype R: TextRange<Index>

    init(_ string: String)

    func addLayoutManager(_ layoutManager: LayoutManager<Self>)
    func removeLayoutManager(_ layoutManager: LayoutManager<Self>)

//    var documentRange: R { get }
//    func textElements(for range: R) -> [TextElement]
}
