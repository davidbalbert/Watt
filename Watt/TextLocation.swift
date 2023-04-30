//
//  TextLocation.swift
//  Watt
//
//  Created by David Albert on 4/29/23.
//

import Foundation

protocol TextLocation {
    func compare(_ location: TextLocation) -> ComparisonResult
}

extension TextLocation {
    static func == (lhs: any TextLocation, rhs: TextLocation) -> Bool {
        lhs.compare(rhs) == .orderedSame
    }

    static func != (lhs: TextLocation, rhs: TextLocation) -> Bool {
        lhs.compare(rhs) != .orderedSame
    }

    static func < (lhs: TextLocation, rhs: TextLocation) -> Bool {
        lhs.compare(rhs) == .orderedAscending
    }

    static func > (lhs: TextLocation, rhs: TextLocation) -> Bool {
        lhs.compare(rhs) == .orderedDescending
    }

    static func <= (lhs: TextLocation, rhs: TextLocation) -> Bool {
        lhs.compare(rhs) == .orderedSame || lhs.compare(rhs) == .orderedAscending
    }

    static func >= (lhs: TextLocation, rhs: TextLocation) -> Bool {
        lhs.compare(rhs) == .orderedSame || lhs.compare(rhs) == .orderedDescending
    }
}
