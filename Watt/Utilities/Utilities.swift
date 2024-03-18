//
//  Utilities.swift
//  Watt
//
//  Created by David Albert on 8/30/23.
//

import Foundation

func isEqual(_ a: Any?, _ b: Any?) -> Bool {
    switch (a, b) {
    case (.none, .none):
        return true
    case (.none, .some(_)):
        return false
    case (.some(_), .none):
        return false
    case let (.some(a), .some(b)):
        func helper<E>(_ a: E) -> Bool where E: Equatable {
            if let b = b as? E {
                return a == b
            } else {
                return false
            }
        }

        guard let a = a as? any Equatable else {
            return false
        }

        return helper(a)
    }
}

func zip4<A, B, C, D>(_ a: A, _ b: B, _ c: C, _ d: D) -> some Sequence<(A.Element, B.Element, C.Element, D.Element)> where A: Sequence, B: Sequence, C: Sequence, D: Sequence {
    zip(zip(a, b), zip(c, d)).map { ($0.0.0, $0.0.1, $0.1.0, $0.1.1) }
}
