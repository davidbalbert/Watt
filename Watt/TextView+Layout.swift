//
//  TextView+Layout.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

extension TextView: LayoutManagerDelegate {
    override func layout() {
        layoutManager.layoutViewport()
    }

    func viewportBounds(for layoutManager: LayoutManager) -> CGRect {
        var viewportBounds: CGRect
        if preparedContentRect.intersects(visibleRect) {
            viewportBounds = preparedContentRect.union(visibleRect)
        } else {
            viewportBounds = visibleRect
        }

        viewportBounds.size.width = bounds.width

        return viewportBounds
    }

    func layoutManagerWillLayout(_ layoutManager: LayoutManager) {
        print("willLayout")
    }

    func layoutManager(_ layoutManager: LayoutManager, configureRenderingSurfaceFor layoutFragment: LayoutFragment) {
        print("configureRenderingSurface")
    }

    func layoutManagerDidLayout(_ layoutManager: LayoutManager) {
        print("didLayout")
    }
}
