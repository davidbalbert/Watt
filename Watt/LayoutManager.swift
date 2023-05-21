//
//  LayoutManager.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation
import CoreText

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

        enumerateLayoutFragments(from: range.lowerBound, options: .ensuresLayout) { layoutFragment in
            for lineFragment in layoutFragment.lineFragments {
                let lineRangeInDocument = lineFragment.textRange

                // I think the only possible empty lineFragment would be the
                // last line of a document if it's empty. I don't know if we
                // represent those yet, but let's ignore them for now.
                guard !lineRangeInDocument.isEmpty else {
                    return false
                }

                let rangeInLineInDocument = range.clamped(to: lineRangeInDocument)
                if rangeInLineInDocument.isEmpty {
                    continue
                }

                let start = contentManager.offset(from: lineRangeInDocument.lowerBound, to: rangeInLineInDocument.lowerBound)
                let end = contentManager.offset(from: lineRangeInDocument.lowerBound, to: rangeInLineInDocument.upperBound)
                let lineEnd = contentManager.offset(from: lineRangeInDocument.lowerBound, to: lineRangeInDocument.upperBound)

                let x0 = lineFragment.locationForCharacter(at: start).x // segment start
                let x1 = lineFragment.locationForCharacter(at: end).x // segment end
                let x2 = lineFragment.locationForCharacter(at: lineEnd).x   // line end
                let xEnd = textContainer.width - 2*textContainer.lineFragmentPadding   // text container end

                let bounds = lineFragment.typographicBounds
                let origin = lineFragment.position

                // in layoutFragment coordinates
                var segmentRect = CGRect(x: x0, y: origin.y, width: min(x1 - x0, xEnd - x0), height: bounds.height)
                let trailingRect = CGRect(x: x2, y: origin.y, width: max(0, xEnd - x2), height: bounds.height)

                var skipTrailing = false

                // if we're getting selection rects, and the selection includes a trailing newline
                // in this line fragment, extend the segment rect to include the selection rect.
                if type == .selection && lineRangeInDocument.upperBound == rangeInLineInDocument.upperBound {
                    if lineFragment.endsWithNewline {
                        segmentRect = segmentRect.union(trailingRect)
                        skipTrailing = true
                    }
                }

                if !block(convert(segmentRect, from: layoutFragment)) {
                    return false
                }

                if range.upperBound <= lineRangeInDocument.upperBound {
                    // we're at the end of our selection
                    return false
                }

                if type == .selection && !skipTrailing && trailingRect.width > 0 {
                    if !block(convert(trailingRect, from: layoutFragment)) {
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
                    layout(frag, at: CGPoint(x: 0, y: y), in: textContainer)
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

        return contentManager.location(lineFragment.textRange.lowerBound, offsetBy: offsetInLine)
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

    func layout(_ layoutFragment: LayoutFragment, at position: CGPoint, in textContainer: TextContainer) {
        guard let contentManager else {
            return
        }

        if layoutFragment.hasLayout {
            print("warning: layout(_:at:in:) called on fragment that already has layout")
            return
        }

        layoutFragment.position = position

        let s = layoutFragment.textElement.attributedString

        // TODO: docs say typesetter can be NULL, but this returns a CTTypesetter, not a CTTypesetter? What happens if this returns NULL?
        let typesetter = CTTypesetterCreateWithAttributedString(s)

        var width: CGFloat = 0
        var height: CGFloat = 0
        var i = 0
        var startIndex = layoutFragment.textRange.lowerBound

        while i < s.length {
            let next = i + CTTypesetterSuggestLineBreak(typesetter, i, textContainer.lineWidth)
            let line = CTTypesetterCreateLine(typesetter, CFRange(location: i, length: next - i))

            let p = CGPoint(x: 0, y: height)
            let (glyphOrigin, typographicBounds) = lineMetrics(for: line, in: textContainer)

            let end = s.string.index(s.string.startIndex, offsetBy: next-1)
            let lastChar = s.string[end]

            let nextIndex = contentManager.location(startIndex, offsetBy: next - i)

            let lineFragment = LineFragment(line: line, glyphOrigin: glyphOrigin, position: p, typographicBounds: typographicBounds, textRange: startIndex..<nextIndex, characterOffset: i, endsWithNewline: lastChar == "\n")
            layoutFragment.lineFragments.append(lineFragment)

            i = next
            startIndex = nextIndex
            width = max(width, typographicBounds.width)
            height += typographicBounds.height
        }

        layoutFragment.typographicBounds = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        layoutFragment.hasLayout = true
    }

    // returns glyphOrigin, typographicBounds
    func lineMetrics(for line: CTLine, in textContainer: TextContainer) -> (CGPoint, CGRect) {
        let ctTypographicBounds = CTLineGetBoundsWithOptions(line, [])

        let paddingWidth = 2*textContainer.lineFragmentPadding

        // ctTypographicBounds's coordinate system has the glyph origin at (0,0).
        // Here, we assume that the glyph origin lies on the left edge of
        // ctTypographicBounds. If it doesn't, we'd have to change our calculation
        // of typographicBounds's origin, though everything else should just work.
        assert(ctTypographicBounds.minX == 0)

        // defined to have the origin in the upper left corner
        let typographicBounds = CGRect(x: 0, y: 0, width: ctTypographicBounds.width + paddingWidth, height: floor(ctTypographicBounds.height))

        let glyphOrigin = CGPoint(
            x: ctTypographicBounds.minX + textContainer.lineFragmentPadding,
            y: floor(ctTypographicBounds.height + ctTypographicBounds.minY)
        )

        return (glyphOrigin, typographicBounds)
    }
}
