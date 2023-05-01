//
//  LayoutManager.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

protocol LayoutManagerDelegate: AnyObject {
    func viewportBounds(for layoutManager: LayoutManager) -> CGRect
    func layoutManagerWillLayout(_ layoutManager: LayoutManager)
    func layoutManager(_ layoutManager: LayoutManager, configureRenderingSurfaceFor layoutFragment: LayoutFragment)
    func layoutManagerDidLayout(_ layoutManager: LayoutManager)
}

class LayoutManager {
    var viewportBounds: CGRect = .zero
    weak var delegate: LayoutManagerDelegate?
    weak var storage: TextStorage?

    lazy var heightEstimates: [CGFloat] = initialHeightEstimates()

    func layoutViewport() {
        guard let delegate else {
            return
        }

        viewportBounds = delegate.viewportBounds(for: self)

        delegate.layoutManagerWillLayout(self)

        let viewportRange = textRange(for: viewportBounds)

        enumerateLayoutFragments(from: viewportRange.start, options: .ensuresLayout) { layoutFragment in
            delegate.layoutManager(self, configureRenderingSurfaceFor: layoutFragment)

            return !layoutFragment.textRange.contains(viewportRange.end)
        }


        delegate.layoutManagerDidLayout(self)
    }

    func initialHeightEstimates() -> [CGFloat] {
        guard let storage else {
            return []
        }

        let count = storage.textElements(for: storage.documentRange).count
        let lineHeight: CGFloat = 10

        return Array(repeating: lineHeight, count: count)
    }

    func textRange(for rect: CGRect) -> TextRange {
        storage?.documentRange ?? NullTextRange()
    }

    func enumerateLayoutFragments(from location: TextLocation, options: LayoutFragment.EnumerationOptions = [], using block: (LayoutFragment) -> Bool) {
        guard let storage else {
            return
        }

        storage.enumerateTextElements(from: location) { el in
            var frag = LayoutFragment(textElement: el)

            if options.contains(.ensuresLayout) {
                frag.layout()
            }

            return block(frag)
        }
    }
}
