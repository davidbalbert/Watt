//
//  Range+Extensions.swift
//  Watt
//
//  Created by David Albert on 2/22/24.
//

import Foundation

extension Range where Bound: Strideable, Bound.Stride: SignedInteger {
    func offset(by offset: Bound.Stride) -> Self {
        lowerBound.advanced(by: offset)..<upperBound.advanced(by: offset)
    }
}
