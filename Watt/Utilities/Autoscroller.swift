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

class Autoscroller {
    private weak var view: NSView?
    private let runloop: RunLoop
    private let mode: RunLoop.Mode
    private let callback: (NSPoint) -> Void

    private (set) var locationInWindow: NSPoint

    private(set) var running: Bool
    private var displayLink: CADisplayLink!

    init(_ view: NSView, event: NSEvent, runloop: RunLoop = .main, mode: RunLoop.Mode = .common, using block: @escaping (CGPoint) -> Void) {
        self.view = view
        self.runloop = runloop
        self.mode = mode
        self.callback = block
        self.locationInWindow = event.locationInWindow

        self.running = false
        self.displayLink = view.displayLink(target: self, selector: #selector(tick(_:)))
    }

    deinit {
        stop()
    }

    func update(with event: NSEvent) {
        precondition(mouseEvents.contains(event.type), "Expected mouse event but got \(event.type).")
        locationInWindow = event.locationInWindow
    }

    func start() {
        if running || view == nil {
            return
        }
        displayLink.add(to: runloop, forMode: mode)
        running = true
    }

    func stop() {
        if !running {
            return
        }
        displayLink.remove(from: runloop, forMode: mode)
        running = false
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

        let slowdown: CGFloat = 16
        let maxScroll: CGFloat = 256

        let dx: CGFloat
        if view.bounds.width <= viewportBounds.width {
            dx = 0
        } else if locationInView.x <= viewportBounds.minX {
            let d = (viewportBounds.minX - locationInView.x) / slowdown
            let scaled = min(maxScroll, d*d)
            dx = -scaled
        } else if locationInView.x >= viewportBounds.maxX {
            let d = (locationInView.x - viewportBounds.maxX) / slowdown
            let scaled = min(maxScroll, d*d)
            dx = scaled
        } else {
            dx = 0
        }

        let dy: CGFloat
        if view.bounds.height <= viewportBounds.height {
            dy = 0
        } else if locationInView.y <= viewportBounds.minY {
            let d = (viewportBounds.minY - locationInView.y) / slowdown
            let scaled = min(maxScroll, d*d)
            dy = -scaled
        } else if locationInView.y >= viewportBounds.maxY {
            let d = (locationInView.y - viewportBounds.maxY) / slowdown
            let scaled = min(maxScroll, d*d)
            dy = scaled
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

        callback(locationInView)
    }
}
