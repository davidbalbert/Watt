//
//  LayoutManagerDelegate.swift
//  Watt
//
//  Created by David Albert on 5/11/23.
//

import Foundation

protocol LayoutManagerDelegate<Storage>: AnyObject {
    associatedtype Storage: TextStorage

    func viewportBounds(for layoutManager: LayoutManager<Storage>) -> CGRect
    func layoutManagerWillLayout(_ layoutManager: LayoutManager<Storage>)
    func layoutManager(_ layoutManager: LayoutManager<Storage>, configureRenderingSurfaceFor layoutFragment: LayoutFragment<Storage>)
    func layoutManagerDidLayout(_ layoutManager: LayoutManager<Storage>)
}
