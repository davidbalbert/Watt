//
//  Autoscroller.swift
//  Watt
//
//  Created by David Albert on 3/18/24.
//

import Cocoa

fileprivate let mouseEvents: [NSEvent.EventType] = [
    .leftMouseDown,
    .leftMouseUp,
    .leftMouseDragged,
    .rightMouseDown,
    .rightMouseUp,
    .rightMouseDragged,
    .otherMouseUp,
    .otherMouseDown,
    .otherMouseDragged,
    .mouseMoved
]

// A helper for smooth autoscrolling.
class Autoscroller {
    // TODO: for whatever reason, I'm not actually able to get 120 Hz working on my M1 MacBook Pro. Investigate.
    static var preferredFrameRateRange: CAFrameRateRange {
        // Apple recommends min=80 max=120 preferred=120 for 120 Hz displays. https://developer.apple.com/documentation/quartzcore/optimizing_promotion_refresh_rates_for_iphone_13_pro_and_ipad_pro

        let max: Float = Float(NSScreen.screens.map(\.maximumFramesPerSecond).max() ?? 60)
        let min: Float = max >= 80.0 ? 80.0 : 60.0

        return CAFrameRateRange(minimum: min, maximum: max, preferred: max)
    }

    private weak var view: NSView?
    private let callback: (NSPoint) -> Void

    private var locationInWindow: NSPoint

    // For small enough dx and dy, the scroll view doesn't end up scrolling. When that happens, accumulate
    // the dx and dy each frame so that we can still scroll when the pointer is very close to the edge of
    // the view.
    private var dxRemainder: CGFloat
    private var dyRemainder: CGFloat

    private(set) var enabled: Bool
    private var displayLink: CADisplayLink!

    init(_ view: NSView, event: NSEvent, using block: @escaping (NSPoint) -> Void) {
        self.view = view
        self.callback = block
        self.locationInWindow = event.locationInWindow

        self.dxRemainder = 0
        self.dyRemainder = 0

        self.enabled = false
        self.displayLink = view.displayLink(target: self, selector: #selector(tick(_:)))

        displayLink.preferredFrameRateRange = Self.preferredFrameRateRange
    }

    deinit {
        stop()
    }

    func update(with event: NSEvent) {
        precondition(mouseEvents.contains(event.type), "Expected mouse event but got \(event.type).")
        locationInWindow = event.locationInWindow

        if displayLink.isPaused, let view {
            let locationInView = view.convert(locationInWindow, from: nil)
            callback(locationInView)
        }

        if displayLink.isPaused != shouldPauseDisplayLink() {
            displayLink.isPaused.toggle()
        }
    }

    private func shouldPauseDisplayLink() -> Bool {
        guard let view else {
            return true
        }

        guard let scrollView = view.enclosingScrollView, scrollView.documentView == view else {
            return true
        }

        let locationInView = view.convert(locationInWindow, from: nil)
        let viewportBounds = scrollView.contentView.bounds

        return locationInView.x > viewportBounds.minX && locationInView.x < viewportBounds.maxX &&
            locationInView.y > viewportBounds.minY && locationInView.y < viewportBounds.maxY
    }

    func start() {
        if enabled || view == nil {
            return
        }
        enabled = true
        displayLink.isPaused = shouldPauseDisplayLink()
        displayLink.add(to: .main, forMode: .common)
    }

    func stop() {
        if !enabled {
            return
        }
        enabled = false
        displayLink.remove(from: .main, forMode: .common)
    }

    @objc func tick(_ sender: CADisplayLink) {
        guard let view else {
            stop()
            return
        }

        let locationInView = view.convert(locationInWindow, from: nil)

        guard let scrollView = view.enclosingScrollView, scrollView.documentView == view else {
            callback(locationInView)
            return
        }

        let viewportBounds = scrollView.contentView.bounds
        let dt = sender.targetTimestamp - sender.timestamp
        let hz = (1/dt).rounded()

        // minScroll is set up so that we end up scrolling at least one point per second. On a 2x display
        // where NSScrollView's minimum scroll is 0.5 points (1 physical pixel), this means we scroll a
        // minimum of 0.5 points every half second.
        //
        // maxScroll=256 and slowdown=(1/16) feel right for 60 Hz. To keep the same feel for other refresh
        // rates, we scale these values. Slowdown ends up squared, so we have to scale it by the square root.
        let minScroll: CGFloat = dt
        let maxScroll: CGFloat = 256.0 * (60.0/hz)
        let slowdown: CGFloat = (1.0/16.0) * sqrt(60/hz)

        let dx: CGFloat
        if view.bounds.width <= viewportBounds.width {
            dx = 0
        } else if locationInView.x <= viewportBounds.minX {
            let d = (viewportBounds.minX - locationInView.x) * slowdown
            let scaled = (d*d).clamped(to: minScroll...maxScroll)
            dx = -scaled + min(dxRemainder, 0)
        } else if locationInView.x >= viewportBounds.maxX {
            let d = (locationInView.x - viewportBounds.maxX) * slowdown
            let scaled = (d*d).clamped(to: minScroll...maxScroll)
            dx = scaled + max(dxRemainder, 0)
        } else {
            dx = 0
        }

        let dy: CGFloat
        if view.bounds.height <= viewportBounds.height {
            dy = 0
        } else if locationInView.y <= viewportBounds.minY {
            let d = (viewportBounds.minY - locationInView.y) * slowdown
            let scaled = (d*d).clamped(to: minScroll...maxScroll)
            dy = -scaled + min(dyRemainder, 0)
        } else if locationInView.y >= viewportBounds.maxY {
            let d = (locationInView.y - viewportBounds.maxY) * slowdown
            let scaled = (d*d).clamped(to: minScroll...maxScroll)
            dy = scaled + max(dyRemainder, 0)
        } else {
            dy = 0
        }

        if dx == 0 && dy == 0 {
            callback(locationInView)
            return
        }

        let scrollOffset = viewportBounds.origin
        let x = (scrollOffset.x + dx).clamped(to: 0...(view.bounds.width - viewportBounds.width))
        let y = (scrollOffset.y + dy).clamped(to: 0...(view.bounds.height - viewportBounds.height))

        view.scroll(NSPoint(x: x, y: y))

        // NSClipView rounds its bounds origin and only scrolls when abs(newX-oldX) >= a threshold. Experimentally
        // on a 2x display, that threshold is 0.5. But rather than hardcoding, just check to see if we've actually
        // scrolled, and if we haven't save dy and dx to accumulate on the next frame.
        let newScrollOffset = scrollView.contentView.bounds.origin
        let xScrolled = abs(newScrollOffset.x - scrollOffset.x) > 1e-10
        let yScrolled = abs(newScrollOffset.y - scrollOffset.y) > 1e-10
        dxRemainder = xScrolled ? 0 : dx
        dyRemainder = yScrolled ? 0 : dy

        callback(NSPoint(x: locationInView.x + dx, y: locationInView.y + dy))
    }
}
