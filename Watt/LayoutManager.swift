//
//  LayoutManager.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

class LayoutManager<ContentManager> where ContentManager: TextContentManager {
    typealias Location = ContentManager.Location

    enum SegmentType {
        case standard
        case selection
    }

    var viewportBounds: CGRect = .zero

    var viewportRange: Range<Location>? {
        guard let firstRange = heightEstimates.textRange(for: viewportBounds.origin) else {
            return nil
        }

        let bottom = CGPoint(x: viewportBounds.minX, y: min(heightEstimates.documentHeight, viewportBounds.maxY))

        guard let lastRange = heightEstimates.textRange(for: bottom) else {
            return nil
        }

        return firstRange.lowerBound..<lastRange.upperBound
    }

    var selection: Selection?

    var textContainer: TextContainer? {
        willSet {
            textContainer?.layoutManager = nil
        }
        didSet {
            textContainer?.layoutManager = self
        }
    }
    weak var delegate: (any LayoutManagerDelegate<ContentManager>)?

    weak var contentManager: ContentManager? {
        didSet {
            heightEstimates = HeightEstimates(contentManager: contentManager)
            fragmentCache.removeAll()
        }
    }

    var fragmentCache: FragmentCache = FragmentCache()

    lazy var heightEstimates: HeightEstimates = HeightEstimates(contentManager: contentManager)

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

    func enumerateTextSegments(in range: Range<Location>, type: SegmentType, using block: (CGRect) -> Bool) {
        guard let contentManager, let textContainer else {
            return
        }

        let nsRange = contentManager.nsRange(from: range)

        enumerateLayoutFragments(from: range.lowerBound, options: .ensuresLayout) { layoutFragment in
            let layoutFragmentOffset = contentManager.offset(from: contentManager.documentRange.lowerBound, to: layoutFragment.textRange.lowerBound)

            for lineFragment in layoutFragment.lineFragments {
                let lineRange = lineFragment.characterRange

                let lineRangeInDocument = NSRange(location: layoutFragmentOffset + lineFragment.characterOffset, length: lineFragment.characterRange.length)

                // I think the only possible lineFragment with a length of 0 would
                // be the last line of a document if it's empty. I don't know if we
                // represent those yet, but let's ignore them for now.
                guard lineRangeInDocument.length > 0 else {
                    return false
                }

                guard let rangeInLineInDocument = nsRange.intersection(lineRangeInDocument) else {
                    continue
                }

                let rangeInLine = NSRange(location: rangeInLineInDocument.location - layoutFragmentOffset - lineFragment.characterOffset, length: rangeInLineInDocument.length)

                let x0 = lineFragment.locationForCharacter(at: rangeInLine.lowerBound).x // segment start
                let x1 = lineFragment.locationForCharacter(at: rangeInLine.upperBound).x // segment end
                let x2 = lineFragment.locationForCharacter(at: lineRange.upperBound).x   // line end
                let xEnd = textContainer.width - textContainer.lineFragmentPadding   // text container end

                let bounds = lineFragment.typographicBounds
                let origin = lineFragment.position

                // in layoutFragment coordinates
                var segmentRect = CGRect(x: x0, y: origin.y, width: x1 - x0, height: bounds.height)
                let trailingRect = CGRect(x: x2, y: origin.y, width: xEnd - x2, height: bounds.height)

                var skipTrailing = false

                // if we're getting selection rects, and the selection includes a trailing newline
                // in this line fragment, extend the segment rect to include the selection rect.
                if type == .selection && lineRangeInDocument.upperBound == rangeInLineInDocument.upperBound {
                    let documentStart = contentManager.documentRange.lowerBound

                    // should never be nil because we know lineRange.length is > 0, but maybe there's
                    // a better way than force unwrapping
                    let lastIdx = contentManager.location(documentStart, offsetBy: lineRangeInDocument.upperBound-1)!
                    let lastChar = contentManager.character(at: lastIdx)

                    if lastChar == "\n" {
                        segmentRect = segmentRect.union(trailingRect)
                        skipTrailing = true
                    }
                }

                if !block(convert(segmentRect, from: layoutFragment)) {
                    return false
                }

                if nsRange.upperBound <= lineRangeInDocument.upperBound {
                    // we're at the end of our selection
                    return false
                }

                if type == .selection && !skipTrailing {
                    if !block(convert(segmentRect, from: layoutFragment)) {
                        return false
                    }
                }
            }

            return true
        }
    }

    func convert(_ rect: CGRect, from layoutFragment: LayoutFragment) -> CGRect {
        let fragX = layoutFragment.frame.minX
        let fragY = layoutFragment.frame.minY
        let origin = CGPoint(x: rect.minX + fragX, y: rect.minY + fragY)

        return CGRect(origin: origin, size: rect.size)
    }

    func convert(_ point: CGPoint, to layoutFragment: LayoutFragment) -> CGPoint {
        CGPoint(x: point.x - layoutFragment.frame.minX, y: point.y - layoutFragment.frame.minY)
    }

    func convert(_ point: CGPoint, to lineFragment: LineFragment) -> CGPoint {
        CGPoint(x: point.x - lineFragment.frame.minX, y: point.y - lineFragment.frame.minY)
    }

    func enumerateLayoutFragments(from location: Location, options: EnumerationOptions = [], using block: (LayoutFragment) -> Bool) {
        guard let contentManager, let textContainer else {
            return
        }

        var lineno: Int = 0
        var y: CGFloat = 0

        if options.contains(.ensuresLayout), let (line, offset) = heightEstimates.lineNumberAndOffset(containing: location) {
            lineno = line
            y = offset
        }

        contentManager.enumerateTextElements(from: location) { el in
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

                frag.lineNumber = lineno

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

    var lineCount: Int {
        heightEstimates.lineCount
    }

    // Returns the closest location
    func location(for point: CGPoint) -> Location? {
        guard let contentManager else {
            return nil
        }

        guard let layoutFragment = layoutFragment(for: point) else {
            return nil
        }

        let pointInLayoutFragment = convert(point, to: layoutFragment)

        var lineStart = 0
        var lineFragment: LineFragment?
        for frag in layoutFragment.lineFragments {
            let frame = frag.frame
            if (frame.minY..<frame.maxY).contains(pointInLayoutFragment.y) {
                lineFragment = frag
                break
            }

            lineStart += frag.characterRange.length
        }

        guard let lineFragment else {
            return nil
        }

        let pointInLineFragment = convert(pointInLayoutFragment, to: lineFragment)
        let offsetInLine = lineFragment.characterIndex(for: pointInLineFragment)

        return contentManager.location(layoutFragment.textRange.lowerBound, offsetBy: lineStart + offsetInLine)
    }

    func layoutFragment(for point: CGPoint) -> LayoutFragment? {
        guard let range = heightEstimates.textRange(for: point) else {
            return nil
        }

        var layoutFragment: LayoutFragment?
        enumerateLayoutFragments(from: range.lowerBound, options: .ensuresLayout) { f in
            layoutFragment = f
            return false
        }

        return layoutFragment
    }
}
