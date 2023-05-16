//
//  LayoutManagerDelegate.swift
//  Watt
//
//  Created by David Albert on 5/11/23.
//

import Foundation

protocol LayoutManagerDelegate<Content>: AnyObject {
    associatedtype Content: ContentManager

    func viewportBounds(for layoutManager: LayoutManager<Content>) -> CGRect
    func layoutManagerWillLayout(_ layoutManager: LayoutManager<Content>)
    func layoutManager(_ layoutManager: LayoutManager<Content>, configureRenderingSurfaceFor layoutFragment: LayoutManager<Content>.LayoutFragment)
    func layoutManagerDidLayout(_ layoutManager: LayoutManager<Content>)
}
