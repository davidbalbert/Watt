//
//  TextView+Layout.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

extension TextView: LayoutManagerDelegate {
    func viewportBounds(for layoutManager: LayoutManager<Storage>) -> CGRect {
        var viewportBounds: CGRect
        if preparedContentRect.intersects(visibleRect) {
            viewportBounds = preparedContentRect.union(visibleRect)
        } else {
            viewportBounds = visibleRect
        }

        viewportBounds.size.width = bounds.width

        return viewportBounds
    }

    func layoutManagerWillLayout(_ layoutManager: LayoutManager<Storage>) {
        print("willLayout")
    }

    func layoutManager(_ layoutManager: LayoutManager<Storage>, configureRenderingSurfaceFor layoutFragment: LayoutFragment) {
        print("configureRenderingSurface")
    }

    func layoutManagerDidLayout(_ layoutManager: LayoutManager<Storage>) {
        print("didLayout")
    }
}
