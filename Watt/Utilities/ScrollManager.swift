//
//  ScrollManager.swift
//  Watt
//
//  Created by David Albert on 3/20/24.
//

import Cocoa
import Motion

protocol ScrollManagerDelegate: AnyObject {
    // Called once for every call to documentRect(_:didResizeTo:) that performs a scroll correction.
    // Can be called multiple times for each call to scrollmanager(_:didCorrectScrollBy:).
    func scrollManager(_ scrollManager: ScrollManager, willCorrectScrollBy delta: CGVector)

    // Called once per run loop tick where scroll correction was performed. One call to this method
    // can correspond to multiple calls to scrollManager(_:willCorrectScrollBy:).
    func scrollManagerDidCorrectScroll(_ scrollManager: ScrollManager)
}

extension ScrollManagerDelegate {
    func scrollManager(_ scrollManager: ScrollManager, willCorrectScrollBy delta: CGVector) {}
    func scrollManagerDidCorrectScroll(_ scrollManager: ScrollManager) {}
}

@MainActor
class ScrollManager {
    private(set) weak var view: NSView?
    private(set) var isDraggingScroller: Bool

    // Think model and presentation layers in Core Animation
    struct PresentationProperties {
        var scrollOffset: CGPoint
    }
    private(set) var scrollOffset: CGPoint
    private(set) var presentation: PresentationProperties

    private var prevPresentationScrollOffset: CGPoint

    private var delta: CGVector

    private var isScrollCorrectionScheduled: Bool

    private var animation: SpringAnimation<CGPoint>?

    var isAnimating: Bool {
        animation != nil
    }

    weak var delegate: ScrollManagerDelegate?

    init(_ view: NSView) {
        self.view = view
        self.isDraggingScroller = false
        self.scrollOffset = .zero
        self.presentation = PresentationProperties(scrollOffset: .zero)
        self.prevPresentationScrollOffset = .zero
        self.delta = .zero
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

        let offset = view?.enclosingScrollView?.contentView.bounds.origin ?? .zero
        scrollOffset = offset
        presentation.scrollOffset = offset
        prevPresentationScrollOffset = offset
        delta = .zero

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

    func documentRect(_ rect: NSRect, didResizeTo newSize: NSSize) {
        guard let scrollView = view?.enclosingScrollView else {
            return
        }

        assert(presentation.scrollOffset == scrollView.contentView.bounds.origin)

        // When animating upwards, any size change with an origin above the viewport contributes
        // to scroll correction. When animating downwards, size changes with origins in the viewport
        // also contribute.
        let movingRight = presentation.scrollOffset.x > prevPresentationScrollOffset.x
        let movingDown = presentation.scrollOffset.y > prevPresentationScrollOffset.y

        let viewport = scrollView.contentView.bounds
        let anchorX = movingRight ? 1.0 : 0.0
        let anchorY = movingDown ? 1.0 : 0.0

        // TODO: I think this should actually be maxX and maxY, but that jumps when scrolling up. See https://dave.is/worklog/2023/07/24/adjusting-scroll-offset-when-document-height-changes/
        let dx = rect.minX >= scrollOffset.x + (anchorX*viewport.width) ? 0 : newSize.width - rect.width
        let dy = rect.minY >= scrollOffset.y + (anchorY*viewport.height) ? 0 : newSize.height - rect.height

        if dx == 0 && dy == 0 {
            return
        }

        delta += CGVector(dx: dx, dy: dy)

        delegate?.scrollManager(self, willCorrectScrollBy: CGVector(dx: dx, dy: dy))

        scrollOffset = CGPoint(x: scrollOffset.x + dx, y: scrollOffset.y + dy)
        scheduleScrollCorrection()
    }

    @objc func viewDidScroll(_ notification: Notification) {
        guard let scrollView = view?.enclosingScrollView else {
            return
        }

        assert(scrollView.contentView == (notification.object as? NSView))

        prevPresentationScrollOffset = presentation.scrollOffset

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

        if isDraggingScroller {
            scheduleScrollCorrection()
        }
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

        defer { delta = .zero }

        isScrollCorrectionScheduled = false
        guard let scrollView = view?.enclosingScrollView else {
            return
        }

        // Dragging a scroller is equivalent to telling the scroll view "please set your offset to this
        // fixed percentage through the document." In this case, scroll correction just consists of
        // reading the percentage out of the scrollers and setting the new origin if the document size
        // has changed.
        if isDraggingScroller {
            assert(!isAnimating)
            assert(scrollView.documentView != nil)

            guard let documentSize = scrollView.documentView?.frame.size else {
                return
            }

            let viewport = scrollView.contentView.bounds
            let offset = NSPoint(
                x: CGFloat(scrollView.horizontalScroller?.floatValue ?? 0) * (documentSize.width - viewport.width),
                y: CGFloat(scrollView.verticalScroller?.floatValue ?? 0) * (documentSize.height - viewport.height)
            )

            if viewport.origin != offset {
                scrollView.documentView?.scroll(offset)
                delegate?.scrollManagerDidCorrectScroll(self)
            }
            return
        }

        let viewport = scrollView.contentView.bounds
        if viewport.origin != scrollOffset {
            if isAnimating {
                scrollView.documentView?.scroll(presentation.scrollOffset + delta)
                animateScroll(to: scrollOffset)
                delegate?.scrollManagerDidCorrectScroll(self)
            } else {
                scrollView.documentView?.scroll(scrollOffset)
                delegate?.scrollManagerDidCorrectScroll(self)
            }
        }
    }
}
