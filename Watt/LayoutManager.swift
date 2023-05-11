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
    var textContainer: TextContainer? {
        willSet {
            textContainer?.layoutManager = nil
        }
        didSet {
            textContainer?.layoutManager = self
        }
    }
    weak var delegate: LayoutManagerDelegate?

    weak var storage: TextStorage? {
        didSet {
            heightEstimates = HeightEstimates(storage: storage)
        }
    }

    lazy var heightEstimates: HeightEstimates = HeightEstimates(storage: storage)
    var layoutFragments: [LayoutFragment]?

    func layoutViewport() {
        guard let delegate else {
            return
        }

        viewportBounds = delegate.viewportBounds(for: self)

        delegate.layoutManagerWillLayout(self)

        guard let firstElement = textElement(for: viewportBounds.origin) else {
            delegate.layoutManagerDidLayout(self)
            return
        }

        enumerateLayoutFragments(from: firstElement.textRange.start, options: .ensuresLayout) { layoutFragment in
            delegate.layoutManager(self, configureRenderingSurfaceFor: layoutFragment)

            let lowerLeftCorner = CGPoint(x: viewportBounds.minX, y: viewportBounds.maxY)

            return !layoutFragment.frame.contains(lowerLeftCorner)
        }

        delegate.layoutManagerDidLayout(self)
    }

    func textElement(for position: CGPoint) -> TextElement? {
        guard let textRange = heightEstimates.textRange(for: position) else {
            return nil
        }

        return storage?.firstTextElement(in: textRange)
    }

    func initialHeightEstimates() -> [CGFloat] {
        guard let storage else {
            return []
        }

        let count = storage.textElements(for: storage.documentRange).count
        let lineHeight: CGFloat = 10

        return Array(repeating: lineHeight, count: count)
    }

    func enumerateLayoutFragments(from location: TextLocation, options: LayoutFragment.EnumerationOptions = [], using block: (LayoutFragment) -> Bool) {
        guard let storage, let textContainer else {
            return
        }

        // TODO: right now, we're just caching everything. Things can't stay this way.
        if let layoutFragments {
            for frag in layoutFragments {
                if !block(frag) {
                    return
                }
            }
            return
        }

        var fragments: [LayoutFragment] = []
        var y: CGFloat = 0

        storage.enumerateTextElements(from: location) { el in
            let frag = LayoutFragment(position: CGPoint(x: 0, y: y), textElement: el)

            if options.contains(.ensuresLayout) {
                frag.layout(in: textContainer)
            }
            // TODO: this assumes we're actually doing layout
            y += frag.typographicBounds.height

            fragments.append(frag)

            return block(frag)
        }

        layoutFragments = fragments
    }

    func invalidateLayout() {
        layoutFragments = nil
    }
}
