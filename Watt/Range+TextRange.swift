//
//  Range+TextRange.swift
//  Watt
//
//  Created by David Albert on 4/30/23.
//

import Foundation

extension Range: TextRange where Bound: TextLocation {
    var start: TextLocation {
        lowerBound
    }

    var end: TextLocation {
        upperBound
    }
}
