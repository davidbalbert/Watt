//
//  String+Extensions.swift
//  Watt
//
//  Created by David Albert on 9/10/23.
//

import Foundation

extension StringProtocol {
    func index(at offset: Int) -> Index {
        index(startIndex, offsetBy: offset)
    }

    func utf8Index(at offset: Int) -> Index {
        utf8.index(startIndex, offsetBy: offset)
    }

    func utf16Index(at offset: Int) -> Index {
        utf16.index(startIndex, offsetBy: offset)
    }

    func unicodeScalarIndex(at offset: Int) -> Index {
        unicodeScalars.index(startIndex, offsetBy: offset)
    }

    // Like withUTF8, but rather than mutating, it just panics if we don't
    // have contiguous UTF-8 storage.
    func withExistingUTF8<R>(_ body: (UnsafeBufferPointer<UInt8>) -> R) -> R {
        utf8.withContiguousStorageIfAvailable { buf in
            body(buf)
        }!
    }
}

