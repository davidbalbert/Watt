//
//  ScrollAnimator.swift
//  Watt
//
//  Created by David Albert on 3/20/24.
//

import Cocoa
import Motion

class ScrollAnimator {
    weak var view: NSView?
    private var animation: SpringAnimation<CGPoint>?

    var isAnimating: Bool {
        animation != nil
    }

    init(_ view: NSView) {
        self.view = view

        if let scrollView = view.enclosingScrollView {
            NotificationCenter.default.addObserver(self, selector: #selector(willStartLiveScroll(_:)), name: NSScrollView.willStartLiveScrollNotification, object: scrollView)
        }
    }

    func scroll(to point: CGPoint) {
        guard let scrollView = view?.enclosingScrollView else {
            return
        }

        let velocity = animation?.velocity ?? .zero
        animation?.stop()

        let spring = SpringAnimation(
            initialValue: scrollView.contentView.bounds.origin,
            response: 0.2,
            dampingRatio: 1.0,
            environment: scrollView
        )

        spring.toValue = point
        spring.velocity = velocity
        spring.resolvingEpsilon = 0.000001

        spring.onValueChanged() { [weak self] value in
            self?.view?.scroll(value)
        }

        spring.completion = { [weak self] in
            self?.animation = nil
        }

        spring.start()
        animation = spring
    }

    func didCorrectScroll(by delta: CGVector) {
        guard let animation else {
            return
        }

        let old = animation.toValue
        let new = CGPoint(x: old.x + delta.dx, y: old.y + delta.dy)

        scroll(to: new)
    }

    @objc func willStartLiveScroll(_ notification: Notification) {
        // If the user interrupts the scroll for any reason, stop the animation.
        animation?.stop()
        animation = nil
    }
}
