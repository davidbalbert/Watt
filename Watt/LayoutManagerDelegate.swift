//
//  LayoutManagerDelegate.swift
//  Watt
//
//  Created by David Albert on 5/11/23.
//

import Foundation

protocol LayoutManagerDelegate: AnyObject {
    func viewportBounds(for layoutManager: LayoutManager) -> CGRect
    func layoutManagerWillLayout(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, configureRenderingSurfaceFor layoutFragment: LayoutFragment)
    func layoutManagerDidLayout(_ layoutManager: LayoutManager)
}
