//
//  SelectionLayerLayout.swift
//  Watt
//
//  Created by David Albert on 5/17/23.
//

import Cocoa

protocol SelectionLayerLayoutDelegate<ContentManager>: AnyObject {
    associatedtype ContentManager: TextContentManager

    func backingScaleFactor(for selectionLayerLayout: SelectionLayerLayout<ContentManager>) -> CGFloat
    func textContainerInsets(for selectionLayerLayout: SelectionLayerLayout<ContentManager>) -> CGSize
}

class SelectionLayerLayout<ContentManager>: NSObject, CALayerDelegate, NSViewLayerContentScaleDelegate where ContentManager: TextContentManager {
    var layoutManager: LayoutManager<ContentManager>
    var layerCache: WeakDictionary<CGRect, CALayer> = WeakDictionary()

    weak var delegate: (any SelectionLayerLayoutDelegate<ContentManager>)?

    init(layoutManager: LayoutManager<ContentManager>) {
        self.layoutManager = layoutManager
    }

    func layoutSublayers(of layer: CALayer) {
        layer.sublayers = nil

        guard let selection = layoutManager.selection else {
            return
        }

        if selection.isEmpty {
            return
        }

        guard let viewportRange = layoutManager.viewportRange else {
            return
        }

        let rangeInViewport = selection.range.clamped(to: viewportRange)

        if rangeInViewport.isEmpty {
            return
        }

        layoutManager.enumerateTextSegments(in: rangeInViewport, type: .selection) { frame in
            let l = layerCache[frame] ?? makeLayer(for: frame)
            layerCache[frame] = l
            layer.addSublayer(l)

            return true
        }
    }

    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        NSNull()
    }

    func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        true
    }

    func makeLayer(for frame: CGRect) -> CALayer {
        let l = CALayer()

        let insets = delegate?.textContainerInsets(for: self) ?? .zero
        let padding = layoutManager.textContainer?.lineFragmentPadding ?? 0

        let position = CGPoint(x: frame.origin.x + insets.width + padding, y: frame.origin.y + insets.height)

        l.anchorPoint = .zero
        l.bounds = CGRect(origin: .zero, size: frame.size)
        l.position = position
        l.contentsScale = delegate?.backingScaleFactor(for: self) ?? 1.0
        l.backgroundColor = NSColor.selectedTextBackgroundColor.cgColor
        l.setNeedsDisplay()

        return l
    }
}
