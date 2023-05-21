//
//  TextView+Selection.swift
//  Watt
//
//  Created by David Albert on 5/19/23.
//

import Cocoa

extension TextView {
    func startSelection(at point: CGPoint) {
        guard let location = layoutManager.location(for: point) else {
            return
        }

        let offset = contentManager.offset(from: contentManager.documentRange.lowerBound, to: location)

        print(offset)
    }

    func extendSelection(to point: CGPoint) {
        guard let location = layoutManager.location(for: point) else {
            return
        }

        let offset = contentManager.offset(from: contentManager.documentRange.lowerBound, to: location)

        print(offset)
    }
}
