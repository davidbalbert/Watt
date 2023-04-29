//
//  LayoutManager.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

protocol LayoutManagerDelegate<Storage>: AnyObject {
    associatedtype Storage: TextStorage

    func viewportBounds(for layoutManager: LayoutManager<Storage>) -> CGRect
    func layoutManagerWillLayout(_ layoutManager: LayoutManager<Storage>)
    func layoutManager(_ layoutManager: LayoutManager<Storage>, configureRenderingSurfaceFor layoutFragment: LayoutFragment)
    func layoutManagerDidLayout(_ layoutManager: LayoutManager<Storage>)
}

class LayoutManager<Storage> where Storage: TextStorage {
    var viewportBounds: CGRect = .zero
    weak var delegate: (any LayoutManagerDelegate<Storage>)?
    weak var storage: Storage? {
        didSet {
            oldValue?.removeLayoutManager(self)
            storage?.addLayoutManager(self)
        }
    }

    var heightEstimates: [CGFloat] = []

    func layoutViewport() {
        guard let delegate else {
            return
        }

        viewportBounds = delegate.viewportBounds(for: self)

        delegate.layoutManagerWillLayout(self)



        delegate.layoutManagerDidLayout(self)
    }

    func updateHeightEstimates() {
//        guard let storage else {
//            heightEstimates = []
//            return
//        }
//
//        let count = storage.textElements(for: storage.documentRange).count
//        let lineHeight: CGFloat = 10
//
//        heightEstimates = Array(repeating: lineHeight, count: count)
    }
}
