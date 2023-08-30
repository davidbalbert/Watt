//
//  Utilities.swift
//  Watt
//
//  Created by David Albert on 8/30/23.
//

import Foundation

fileprivate protocol EquatablePair {
    func perform() -> Bool
}

fileprivate protocol MaybeEquatablePair {
    func maybePerform() -> Bool?
}

fileprivate struct Pair<T> {
    var a: T
    var b: T
}

extension Pair: MaybeEquatablePair {
    func maybePerform() -> Bool? {
        (self as? EquatablePair)?.perform()
    }
}

extension Pair: EquatablePair where T: Equatable {
    func perform() -> Bool {
        a == b
    }
}

func isEqual(_ a: Any?, _ b: Any?) -> Bool {
    switch (a, b) {
    case (.none, .none):
        return true
    case (.none, .some(_)):
        return false
    case (.some(_), .none):
        return false
    case let (.some(a), .some(b)):
        func helper<T>(_ a: T) -> Bool {
            if let b = b as? T {
                return Pair(a: a, b: b).maybePerform() ?? false
            } else {
                return false
            }
        }

        // Swift 6: this can be changed to `return helper(a)`
        return _openExistential(a, do: helper)
    }
}
