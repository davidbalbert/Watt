//
//  TextLayerLayoutDelegate.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import Foundation

protocol TextLayerLayoutDelegate<ContentManager>: AnyObject {
    associatedtype ContentManager: TextContentManager

    func viewportBounds(for textLayerLayout: TextLayerLayout<ContentManager>) -> CGRect

    func textLayerLayoutWillLayout(_ textLayerLayout: TextLayerLayout<ContentManager>)
    func textLayerLayout(_ textLayerLayout: TextLayerLayout<ContentManager>, didLayout layoutFragment: LayoutManager<ContentManager>.LayoutFragment)
    func textLayerLayoutDidFinishLayout(_ textLayerLayout: TextLayerLayout<ContentManager>)

    func backingScaleFactor(for textLayerLayout: TextLayerLayout<ContentManager>) -> CGFloat
    func textLayerLayout(_ textLayerLayout: TextLayerLayout<ContentManager>, insetFor layoutFragment: LayoutManager<ContentManager>.LayoutFragment) -> CGSize
}
