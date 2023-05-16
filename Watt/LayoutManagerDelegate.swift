//
//  LayoutManagerDelegate.swift
//  Watt
//
//  Created by David Albert on 5/11/23.
//

import Foundation

protocol LayoutManagerDelegate<ContentManager>: AnyObject {
    associatedtype ContentManager: TextContentManager

    func viewportBounds(for layoutManager: LayoutManager<ContentManager>) -> CGRect
    func layoutManagerWillLayout(_ layoutManager: LayoutManager<ContentManager>)
    func layoutManager(_ layoutManager: LayoutManager<ContentManager>, configureRenderingSurfaceFor layoutFragment: LayoutManager<ContentManager>.LayoutFragment)
    func layoutManagerDidLayout(_ layoutManager: LayoutManager<ContentManager>)
}
