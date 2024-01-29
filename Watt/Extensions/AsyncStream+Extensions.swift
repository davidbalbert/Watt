//
//  AsyncStream+Extensions.swift
//  Watt
//
//  Created by David Albert on 1/5/24.
//

import Foundation

extension AsyncStream {
    init<Base>(_ base: consuming Base) where Base: AsyncIteratorProtocol, Base.Element == Element {
        self.init {
            try? await base.next()
        }
    }
}
