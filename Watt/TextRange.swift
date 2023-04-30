//
//  TextRange.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

protocol TextRange {
    var start: TextLocation { get }
    var end: TextLocation { get }
    var isEmpty: Bool { get }
}

extension TextRange {
    func contains(_ location: TextLocation) -> Bool {
        (start.compare(location) == .orderedAscending || start.compare(location) == .orderedSame) && location.compare(end) == .orderedAscending
    }
}
