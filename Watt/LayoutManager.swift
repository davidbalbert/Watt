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
    weak var storage: TextStorage?

    lazy var heightEstimates: [CGFloat] = initialHeightEstimates()
    var layoutFragments: [LayoutFragment]?

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
        guard let storage, let textContainer else {
            return
        }

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
