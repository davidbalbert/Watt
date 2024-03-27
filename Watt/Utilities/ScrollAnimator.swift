//
//  ScrollAnimator.swift
//  Watt
//
//  Created by David Albert on 3/20/24.
//

import Cocoa
import Motion

@MainActor
class ScrollAnimator {
    private(set) weak var view: NSView?
    private(set) var isDraggingScroller: Bool

    // Think model and presentation layers in Core Animation
    struct PresentationProperties {
        var scrollOffset: CGPoint
    }
    private(set) var scrollOffset: CGPoint
    private(set) var presentation: PresentationProperties

    // A unit point representing the position of the dragged scroller knobs.
    private var absoluteUnitOffset: CGPoint?

    private var isScrollCorrectionScheduled: Bool

    private var animation: SpringAnimation<CGPoint>?

    var isAnimating: Bool {
        animation != nil
    }

    init(_ view: NSView) {
        self.view = view
        self.isDraggingScroller = false
        self.scrollOffset = .zero
        self.presentation = PresentationProperties(scrollOffset: .zero)
        self.isScrollCorrectionScheduled = false

        if view.superview != nil {
            viewDidMoveToSuperview()
        }
    }

    func viewDidMoveToSuperview() {
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSScrollView.willStartLiveScrollNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSScrollView.didLiveScrollNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSScrollView.didEndLiveScrollNotification, object: nil)

        animation?.stop()
        animation = nil

        isDraggingScroller = false
        isScrollCorrectionScheduled = false

        absoluteUnitOffset = nil

        let offset = view?.enclosingScrollView?.contentView.bounds.origin ?? .zero
        scrollOffset = offset
        presentation.scrollOffset = offset

        if let scrollView = view?.enclosingScrollView {
            NotificationCenter.default.addObserver(self, selector: #selector(viewDidScroll(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
            NotificationCenter.default.addObserver(self, selector: #selector(willStartLiveScroll(_:)), name: NSScrollView.willStartLiveScrollNotification, object: scrollView)
            NotificationCenter.default.addObserver(self, selector: #selector(didLiveScroll(_:)), name: NSScrollView.didLiveScrollNotification, object: scrollView)
            NotificationCenter.default.addObserver(self, selector: #selector(didEndLiveScroll(_:)), name: NSScrollView.didEndLiveScrollNotification, object: scrollView)
        }
    }

    func animateScroll(to point: NSPoint) {
        guard let scrollView = view?.enclosingScrollView else {
            return
        }

        scrollOffset = point

        let velocity = animation?.velocity ?? .zero
        animation?.stop()

        assert(presentation.scrollOffset == scrollView.contentView.bounds.origin)
        let spring = SpringAnimation(
            initialValue: presentation.scrollOffset,
            response: 0.2,
            dampingRatio: 1.0,
            environment: scrollView
        )

        spring.toValue = scrollOffset
        spring.velocity = velocity
        spring.resolvingEpsilon = 0.000001

        spring.onValueChanged() { [weak self] value in
            self?.view?.enclosingScrollView?.documentView?.scroll(value)
        }

        spring.completion = { [weak self] in
            self?.animation = nil
        }

        spring.start()
        animation = spring
    }

    func rectInDocumentViewDidChange(from old: NSRect, to new: NSRect) {
        precondition(old.origin == new.origin, "old and new rects must share an origin")

        guard let scrollView = view?.enclosingScrollView else {
            return
        }

        assert(presentation.scrollOffset == scrollView.contentView.bounds.origin)

        // When animating upwards, any size change with an origin above the viewport contributes
        // to scroll correction. When animating downwards, size changes with origins in the viewport
        // also contribute.
        let viewport = scrollView.contentView.bounds
        let anchorX = scrollOffset.x > presentation.scrollOffset.x ? 1.0 : 0.0
        let anchorY = scrollOffset.y > presentation.scrollOffset.y ? 1.0 : 0.0

        let dx = old.minX >= scrollOffset.x + (anchorX*viewport.width) ? 0 : new.width - old.width
        let dy = old.minY >= scrollOffset.y + (anchorY*viewport.height) ? 0 : new.height - old.height

        if dx == 0 && dy == 0 {
            return
        }

        scrollOffset = CGPoint(x: scrollOffset.x + dx, y: scrollOffset.y + dy)
        scheduleScrollCorrection()
    }

    @objc func viewDidScroll(_ notification: Notification) {
        guard let scrollView = view?.enclosingScrollView else {
            return
        }

        assert(scrollView.contentView == (notification.object as? NSView))

        let offset = scrollView.contentView.bounds.origin
        if isAnimating {
            presentation.scrollOffset = offset
        } else {
            scrollOffset = offset
            presentation.scrollOffset = offset
        }
    }

    @objc func willStartLiveScroll(_ notification: Notification) {
        // If the user interrupts the scroll for any reason, stop the animation.
        animation?.stop()
        animation = nil

        scrollOffset = presentation.scrollOffset

        guard let scrollView = notification.object as? NSScrollView else {
            return
        }

        isDraggingScroller = scrollView.horizontalScroller?.hitPart == .knob || scrollView.verticalScroller?.hitPart == .knob
    }

    @objc func didLiveScroll(_ notification: Notification) {
        guard let scrollView = notification.object as? NSScrollView else {
            return
        }

        // From the didLiveScrollNotification docs: "Some user-initiated scrolls (for example, scrolling
        // using legacy mice) are not bracketed by a "willStart/didEnd” notification pair."
        animation?.stop()
        animation = nil

        assert(scrollView == view?.enclosingScrollView)

        if !isDraggingScroller {
            return
        }

        // scrollView encloses view, so it must have a document view
        assert(scrollView.documentView != nil)
        guard let documentSize = scrollView.documentView?.frame.size else {
            return
        }

        let viewport = scrollView.contentView.bounds

        let unitx: CGFloat
        if let v = scrollView.horizontalScroller?.floatValue {
            unitx = CGFloat(v)
        } else {
            let maxX = max(documentSize.width - viewport.width, 0)
            assert(maxX > 0 || scrollOffset.x == 0)
            unitx = maxX == 0 ? 0 : scrollOffset.x / maxX
        }

        let unity: CGFloat
        if let v = scrollView.verticalScroller?.floatValue {
            unity = CGFloat(v)
        } else {
            let maxY = max(documentSize.height - viewport.height, 0)
            assert(maxY > 0 || scrollOffset.y == 0)
            unity = maxY == 0 ? 0 : scrollOffset.y / maxY
        }

        absoluteUnitOffset = CGPoint(x: unitx, y: unity)
        scheduleScrollCorrection()
    }

    @objc func didEndLiveScroll(_ notification: Notification) {
        isDraggingScroller = false
    }

    private func scheduleScrollCorrection() {
        if isScrollCorrectionScheduled {
            return
        }

        isScrollCorrectionScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.performScrollCorrection()
        }
    }

    private func performScrollCorrection() {
        if !isScrollCorrectionScheduled {
            return
        }

        isScrollCorrectionScheduled = false
        guard let scrollView = view?.enclosingScrollView else {
            return
        }

        if let absoluteUnitOffset {
            defer { self.absoluteUnitOffset = nil }

            assert(!isAnimating)
            assert(scrollView.documentView != nil)

            guard let documentSize = scrollView.documentView?.frame.size else {
                return
            }

            let viewport = scrollView.contentView.bounds
            let offset = NSPoint(
                x: absoluteUnitOffset.x * (documentSize.width - viewport.width),
                y: absoluteUnitOffset.y * (documentSize.height - viewport.height)
            )

            if viewport.origin != offset {
                scrollView.documentView?.scroll(offset)
            }
            return
        }

        let offset = scrollView.contentView.bounds.origin
        if offset != scrollOffset {
            if isAnimating {
                animateScroll(to: scrollOffset)
                assert(offset == presentation.scrollOffset)
            } else {
                scrollView.documentView?.scroll(scrollOffset)
            }
        }
    }
}
