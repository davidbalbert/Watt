//
//  CGRect+Extensions.swift
//  Watt
//
//  Created by David Albert on 5/10/23.
//

import Foundation

extension CGRect {
    var pixelAligned: CGRect {
        NSIntegralRectWithOptions(self, .alignAllEdgesNearest)
    }
}
