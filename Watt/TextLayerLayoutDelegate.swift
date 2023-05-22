//
//  TextLayerLayoutDelegate.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import Foundation

protocol TextLayerLayoutDelegate: AnyObject {
    func viewportBounds(for textLayerLayout: TextLayerLayout) -> CGRect

    func textLayerLayoutWillLayout(_ textLayerLayout: TextLayerLayout)
    func textLayerLayout(_ textLayerLayout: TextLayerLayout, didLayout layoutFragment: LayoutFragment)
    func textLayerLayoutDidFinishLayout(_ textLayerLayout: TextLayerLayout)

    func backingScaleFactor(for textLayerLayout: TextLayerLayout) -> CGFloat
    func textLayerLayout(_ textLayerLayout: TextLayerLayout, insetFor layoutFragment: LayoutFragment) -> CGSize
}
