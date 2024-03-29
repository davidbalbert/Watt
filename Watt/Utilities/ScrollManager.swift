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
    func scrollManagerDidPerformScrollCorrection(_ scrollManager: ScrollManager)
}

extension ScrollManagerDelegate {
    func scrollManager(_ scrollManager: ScrollManager, willCorrectScrollBy delta: CGVector) {}
    func scrollManagerDidPerformScrollCorrection(_ scrollManager: ScrollManager) {}
}

@MainActor
class ScrollManager {
    private(set) weak var view: NSView?
    private(set) var isDraggingScroller: Bool

    private(set) var scrollOffset: CGPoint
    private var prevScrollOffset: CGPoint
    private var delta: CGVector

    private var needsScrollCorrection: Bool

    private var animation: SpringAnimation<CGPoint>?

    var isAnimating: Bool {
        animation != nil
    }

    var animationDestination: CGPoint? {
        animation?.toValue
    }

    weak var delegate: ScrollManagerDelegate?

    private var observer: CFRunLoopObserver?

    init(_ view: NSView) {
        self.view = view
        self.isDraggingScroller = false
        self.scrollOffset = .zero
        self.prevScrollOffset = .zero
        self.delta = .zero
        self.needsScrollCorrection = false

        var context = CFRunLoopObserverContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let observer = CFRunLoopObserverCreate(kCFAllocatorDefault, CFRunLoopActivity.beforeSources.rawValue, true, 0, { observer, activity, info in
            let manager = Unmanaged<ScrollManager>.fromOpaque(info!).takeUnretainedValue()
            manager.performScrollCorrection()
        }, &context)

        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = observer

        if view.superview != nil {
            viewDidMoveToSuperview()
        }
    }

    deinit {
        if let observer {
            CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
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
        needsScrollCorrection = false

        let offset = view?.enclosingScrollView?.contentView.bounds.origin ?? .zero
        scrollOffset = offset
        prevScrollOffset = offset
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

        let velocity = animation?.velocity ?? .zero
        animation?.stop()

        assert(scrollOffset == scrollView.contentView.bounds.origin)
        let spring = SpringAnimation(
            initialValue: scrollOffset,
            response: 0.2,
            dampingRatio: 1.0,
            environment: scrollView
        )

        spring.toValue = point
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

        // If we're dragging the scroller, we're requesting an absolute percent through the document.
        // If layout changed at all while dragging, we're going to be in the wrong place, and need
        // to correct.
        if isDraggingScroller {
            needsScrollCorrection = true
            return
        }

        // When animating upwards, any size change with an origin above the viewport contributes
        // to scroll correction. When animating downwards, size changes with origins in the viewport
        // also contribute.
        let movingRight = scrollOffset.x > prevScrollOffset.x
        let movingDown = scrollOffset.y > prevScrollOffset.y

        let anchorX = movingRight ? 1.0 : 0.0
        let anchorY = movingDown ? 1.0 : 0.0

        assert(scrollOffset == scrollView.contentView.bounds.origin)
        let viewport = scrollView.contentView.bounds

        let dx = rect.maxX <= (animationDestination ?? prevScrollOffset).x + (anchorX*viewport.width) ? newSize.width - rect.width : 0
        let dy = rect.maxY <= (animationDestination ?? prevScrollOffset).y + (anchorY*viewport.height) ? newSize.height - rect.height : 0

        if dx == 0 && dy == 0 {
            return
        }

        delta += CGVector(dx: dx, dy: dy)

        delegate?.scrollManager(self, willCorrectScrollBy: CGVector(dx: dx, dy: dy))
        needsScrollCorrection = true
    }

    @objc func viewDidScroll(_ notification: Notification) {
        guard let scrollView = view?.enclosingScrollView else {
            return
        }

        assert(scrollView.contentView == (notification.object as? NSView))

        prevScrollOffset = scrollOffset
        scrollOffset = scrollView.contentView.bounds.origin
    }

    @objc func willStartLiveScroll(_ notification: Notification) {
        // If the user interrupts the scroll for any reason, stop the animation.
        animation?.stop()
        animation = nil

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
            needsScrollCorrection = true
        }
    }

    @objc func didEndLiveScroll(_ notification: Notification) {
        isDraggingScroller = false
    }

    private func performScrollCorrection() {
        if !needsScrollCorrection {
            return
        }

        // We always want scroll correction to run after layout so that we can take into account any resizing
        // that happens during layout. Layout happens in a .beforeTimers observer, and we run in a .beforeSources
        // observer, which happens later. But there may be any number of iterations through run loop between when
        // needsScrollCorrection is set and layout is run. So if layout hasn't happened yet, bail early.
        if let view, view.needsLayout {
            return
        }

        defer { delta = .zero }
        needsScrollCorrection = false

        guard let scrollView = view?.enclosingScrollView else {
            return
        }

        defer { delegate?.scrollManagerDidPerformScrollCorrection(self) }

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
            }
            return
        }

        if delta != .zero {
            scrollView.documentView?.scroll(scrollOffset + delta)
            if let animation {
                animateScroll(to: animation.toValue + delta)
            }
        }
    }
}
