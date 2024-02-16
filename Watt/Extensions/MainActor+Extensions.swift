//
//  MainActor+Extensions.swift
//  Watt
//
//  Created by David Albert on 2/15/24.
//

import Foundation

extension MainActor {
    @_unavailableFromAsync
    static func unsafeIgnoreActorIsolation<T>(_ operation: @MainActor () throws -> T) rethrows -> T {
        try withoutActuallyEscaping(operation) { fn in
            let rawFn = unsafeBitCast(fn, to: (() throws -> T).self)
            return try rawFn()
        }
    }
}
