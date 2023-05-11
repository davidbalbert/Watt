//
//  LayoutManager.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

class LayoutManager<Storage> where Storage: TextStorage {
    typealias Location = Storage.Location

    var viewportBounds: CGRect = .zero
    var textContainer: TextContainer<Storage>? {
        willSet {
            textContainer?.layoutManager = nil
        }
        didSet {
            textContainer?.layoutManager = self
        }
    }
    weak var delegate: (any LayoutManagerDelegate<Storage>)?

    weak var storage: Storage? {
        didSet {
            heightEstimates = HeightEstimates(storage: storage)
        }
    }

    lazy var heightEstimates: HeightEstimates = HeightEstimates(storage: storage)

    var documentHeight: CGFloat {
        heightEstimates.documentHeight
    }

    func layoutViewport() {
        guard let delegate else {
            return
        }

        viewportBounds = delegate.viewportBounds(for: self)

        delegate.layoutManagerWillLayout(self)

        guard let textRange = heightEstimates.textRange(for: viewportBounds.origin) else {
            delegate.layoutManagerDidLayout(self)
            return
        }

        enumerateLayoutFragments(from: textRange.lowerBound, options: .ensuresLayout) { layoutFragment in
            delegate.layoutManager(self, configureRenderingSurfaceFor: layoutFragment)

            let lowerLeftCorner = CGPoint(x: viewportBounds.minX, y: viewportBounds.maxY)
            return !layoutFragment.frame.contains(lowerLeftCorner)
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

    func enumerateLayoutFragments(from location: Location, options: LayoutFragmentEnumerationOptions = [], using block: (LayoutFragment<Storage>) -> Bool) {
        guard let storage, let textContainer else {
            return
        }

        var lineno: Int = 0
        var y: CGFloat = 0

        if options.contains(.ensuresLayout), let (line, offset) = heightEstimates.lineNumberAndOffset(containing: location) {
            lineno = line
            y = offset
        }

        storage.enumerateTextElements(from: location) { el in
            let frag = LayoutFragment<Storage>(textElement: el)

            if options.contains(.ensuresLayout) {
                frag.layout(at: CGPoint(x: 0, y: y), in: textContainer)
                let height = frag.typographicBounds.height
                heightEstimates.updateFragmentHeight(at: lineno, with: height)
                y += height
                lineno += 1
            }

            return block(frag)
        }
    }

    func invalidateLayout() {
    }
}
