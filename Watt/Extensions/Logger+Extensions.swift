//
//  Logger+Extensions.swift
//  Watt
//
//  Created by David Albert on 2/9/24.
//

import os

extension Logger {
    func enabled(_ enabled: Bool) -> Logger {
        if enabled {
            return self
        } else {
            return Logger(.disabled)
        }
    }
}
