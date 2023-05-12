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
    var textContainer: TextContainer? {
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
            fragmentCache.removeAll()
        }
    }

    var fragmentCache: FragmentCache = FragmentCache()

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

        fragmentCache.removeFragments(before: viewportBounds.origin)
        fragmentCache.removeFragments(after: CGPoint(x: viewportBounds.minX, y: viewportBounds.maxY))

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

    func enumerateLayoutFragments(from location: Location, options: EnumerationOptions = [], using block: (LayoutFragment) -> Bool) {
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
            let cached = fragmentCache.fragment(at: el.textRange.lowerBound)
            let frag = cached ?? LayoutFragment(textElement: el)

            if options.contains(.ensuresLayout) {
                if !frag.hasLayout {
                    frag.layout(at: CGPoint(x: 0, y: y), in: textContainer)
                } else {
                    // Even though we're already laid out, it's possible that a fragment
                    // above us just got laid out for the first time (for example, if we
                    // scrolled to the bottom of the document really fast, missing some
                    // fragments on the way down, and then started scrolling back up). In
                    // this situation, assuming the previously estimated height for our previous
                    // sibling (the fragment that was just laid out) was less than it's actual
                    // height, our origin will be smaller than it needs to be, and we'll overlap
                    // with our previous sibling.
                    //
                    // The good news is that the `y` we're accumulating during layout takes into
                    // account the actual heights of all the fragments that we've laid out in this
                    // pass, which means we can just use it for our position.
                    //
                    // TODO: in the future, we may want to accumulate the deltas and scroll our enclosing
                    // scroll view to compensate.
                    frag.position.y = y
                }

                if cached == nil {
                    fragmentCache.add(frag)
                }

                let height = frag.typographicBounds.height
                heightEstimates.updateFragmentHeight(at: lineno, with: height)
                y += height
                lineno += 1
            }

            return block(frag)
        }
    }

    func invalidateLayout() {
        fragmentCache.removeAll()
    }
}
