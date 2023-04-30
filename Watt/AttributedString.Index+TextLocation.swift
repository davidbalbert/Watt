//
//  AttributedString.Index+TextLocation.swift
//  Watt
//
//  Created by David Albert on 4/30/23.
//

import Foundation

extension AttributedString.Index: TextLocation {
    func compare(_ location: TextLocation) -> ComparisonResult {
        let location = location as! AttributedString.Index

        if self == location {
            return .orderedSame
        } else if self < location {
            return .orderedAscending
        } else {
            return .orderedDescending
        }
    }
}
