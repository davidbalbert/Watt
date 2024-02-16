//
//  Logger+Extensions.swift
//  Watt
//
//  Created by David Albert on 2/9/24.
//

import os

extension Logger {
    public init<T>(type: T.Type) {
        let subsystem = Bundle.main.bundleIdentifier!
        let category = String(describing: T.self)

        self.init(subsystem: subsystem, category: category)
    }

    func enabled(_ enabled: Bool) -> Logger {
        if enabled {
            return self
        } else {
            return Logger(.disabled)
        }
    }
}
