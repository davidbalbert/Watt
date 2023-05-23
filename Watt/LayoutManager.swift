//
//  LayoutManager.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation
import CoreText

class LayoutManager {
    var viewportBounds: CGRect = .zero {
        didSet {
            _viewportRange = nil
        }
    }

    var _viewportRange: Range<String.Index>?

    func calculateViewportRange() -> Range<String.Index>? {
        guard let firstRange = heightEstimates.textRange(for: viewportBounds.origin) else {
            return nil
        }

        let bottom = CGPoint(x: viewportBounds.minX, y: min(heightEstimates.documentHeight, viewportBounds.maxY))

        guard let lastRange = heightEstimates.textRange(for: bottom) else {
            return nil
        }

        return firstRange.lowerBound..<lastRange.upperBound
    }

    var viewportRange: Range<String.Index>? {
        if let _viewportRange {
            return _viewportRange
        }

        _viewportRange = calculateViewportRange()
        return _viewportRange
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

    weak var delegate: LayoutManagerDelegate?

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

    func enumerateSelectionSegments(in range: Range<String.Index>, using block: (CGRect) -> Bool) {
        guard let contentManager, let textContainer else {
            return
        }

        enumerateLayoutFragments(from: range.lowerBound, options: .ensuresLayout) { layoutFragment in
            for lineFragment in layoutFragment.lineFragments {
                let lineRange = lineFragment.textRange

                // I think the only possible empty lineFragment would be the
                // last line of a document if it's empty. I don't know if we
                // represent those yet, but let's ignore them for now.
                guard !lineRange.isEmpty else {
                    return false
                }

                let rangeInLine = range.clamped(to: lineRange)

                if rangeInLine.isEmpty {
                    continue
                }

                let start = contentManager.offset(from: lineRange.lowerBound, to: rangeInLine.lowerBound)
                let xStart = locationForCharacter(atOffset: start, in: lineFragment).x

                let last = contentManager.location(lineRange.upperBound, offsetBy: -1)
                let lastChar = contentManager.character(at: last)
                let shouldExtend = (range.upperBound == lineRange.upperBound && lastChar == "\n") || range.upperBound > lineRange.upperBound

                let xEnd: CGFloat
                if shouldExtend {
                    xEnd = textContainer.lineWidth
                } else {
                    let end = contentManager.offset(from: lineRange.lowerBound, to: rangeInLine.upperBound)
                    let x0 = locationForCharacter(atOffset: end, in: lineFragment).x
                    let x1 = textContainer.lineWidth
                    xEnd = min(x0, x1)
                }

                let bounds = lineFragment.typographicBounds
                let origin = lineFragment.position
                let padding = textContainer.lineFragmentPadding

                // in layout fragment coordinates
                let rect = CGRect(x: xStart + padding, y: origin.y, width: xEnd - xStart, height: bounds.height)

                if !block(convert(rect, from: layoutFragment)) {
                    return false
                }

                if range.upperBound <= lineRange.upperBound {
                    // we're at the end of our selection
                    return false
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

    func convert(_ point: CGPoint, from layoutFragment: LayoutFragment) -> CGPoint {
        CGPoint(
            x: point.x + layoutFragment.frame.minX,
            y: point.y + layoutFragment.frame.minY
        )
    }

    func convert(_ point: CGPoint, to layoutFragment: LayoutFragment) -> CGPoint {
        CGPoint(
            x: point.x - layoutFragment.frame.minX,
            y: point.y - layoutFragment.frame.minY
        )
    }

    func convert(_ point: CGPoint, from lineFragment: LineFragment) -> CGPoint {
        CGPoint(
            x: point.x + lineFragment.frame.minX,
            y: point.y + lineFragment.frame.minY
        )
    }

    func convert(_ point: CGPoint, to lineFragment: LineFragment) -> CGPoint {
        CGPoint(x: point.x - lineFragment.frame.minX, y: point.y - lineFragment.frame.minY)
    }

    func enumerateLayoutFragments(from location: String.Index, options: LayoutFragment.EnumerationOptions = [], using block: (LayoutFragment) -> Bool) {
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

    func location(interactingAt point: CGPoint) -> String.Index? {
        guard let (location, _) = locationAndAffinity(interactingAt: point) else {
            return nil
        }

        return location
    }

    func locationAndAffinity(interactingAt point: CGPoint) -> (String.Index, Selection.Affinity)? {
        guard let contentManager, let textContainer else {
            return nil
        }

        guard let layoutFragment = layoutFragment(for: point) else {
            return nil
        }

        let pointInLayoutFragment = convert(point, to: layoutFragment)

        var lineFragment: LineFragment?
        for frag in layoutFragment.lineFragments {
            let frame = frag.frame
            if (frame.minY..<frame.maxY).contains(pointInLayoutFragment.y) {
                lineFragment = frag
                break
            }
        }

        guard let lineFragment else {
            return nil
        }

        let pointInLineFragment = convert(pointInLayoutFragment, to: lineFragment)
        let adjusted = CGPoint(
            x: pointInLineFragment.x - textContainer.lineFragmentPadding,
            y: pointInLineFragment.y
        )

        let range = CTLineGetStringRange(lineFragment.line)
        var offset = CTLineGetStringIndexForPosition(lineFragment.line, adjusted)

        if offset == kCFNotFound {
            return nil
        }

        let affinity: Selection.Affinity
        if offset == range.location+range.length {
            affinity = .upstream
        } else {
            affinity = .downstream
        }

        let lastIdx = contentManager.location(lineFragment.textRange.upperBound, offsetBy: -1)
        let lastChar = contentManager.character(at: lastIdx)

        if offset == range.location+range.length && lastChar == "\n" {
            offset -= 1
        }

        let location = contentManager.location(layoutFragment.textRange.lowerBound, offsetBy: offset)

        return (location, affinity)
    }

    func enumerateCaretRectsInLineFragment(at location: String.Index, using block: @escaping (CGRect, String.Index, Bool) -> Bool)  {
        guard let contentManager, let textContainer else {
            return
        }

        guard let layoutFragment = layoutFragment(for: location) else {
            return
        }

        guard let lineFragment = layoutFragment.lineFragment(for: location) else {
            return
        }

        var loc = lineFragment.textRange.lowerBound
        var prevCharIndex = 0
        CTLineEnumerateCaretOffsets(lineFragment.line) { [weak self] caretOffset, charIndex, leadingEdge, stop in
            guard let self else {
                stop.pointee = true
                return
            }

            loc = contentManager.location(loc, offsetBy: charIndex - prevCharIndex)
            prevCharIndex = charIndex

            let lineOrigin = CGPoint(x: caretOffset, y: 0)
            let origin = convert(convert(lineOrigin, from: lineFragment), from: layoutFragment)

            let height = lineFragment.typographicBounds.height
            let rect = CGRect(x: origin.x + textContainer.lineFragmentPadding, y: origin.y, width: 1, height: height)

            if !block(rect, loc, leadingEdge) {
                stop.pointee = true
            }
        }
    }

    func layoutFragment(for location: String.Index) -> LayoutFragment? {
        var layoutFragment: LayoutFragment?
        enumerateLayoutFragments(from: location, options: .ensuresLayout) { f in
            layoutFragment = f
            return false
        }

        return layoutFragment
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

            let nextIndex = contentManager.location(startIndex, offsetBy: next - i)

            let lineFragment = LineFragment(line: line, glyphOrigin: glyphOrigin, position: p, typographicBounds: typographicBounds, textRange: startIndex..<nextIndex, characterOffset: i)
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

    func locationForCharacter(atOffset offset: Int, in lineFragment: LineFragment) -> CGPoint {
        CGPoint(x: CTLineGetOffsetForStringIndex(lineFragment.line, offset + lineFragment.characterOffset, nil), y: 0)
    }
}
