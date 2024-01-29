//
//  URL+Extensions.swift
//  Watt
//
//  Created by David Albert on 1/29/24.
//

import Foundation
import System

extension URL {
    func isDescendant(ofFileURL rootURL: URL) -> Bool {
        if !(isFileURL && rootURL.isFileURL) {
            return false
        }

        let path = FilePath(standardizedFileURL.path)
        let root = FilePath(rootURL.standardizedFileURL.path)

        return path.starts(with: root)
    }
}
