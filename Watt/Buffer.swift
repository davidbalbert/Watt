//
//  Buffer.swift
//  Watt
//
//  Created by David Albert on 7/19/23.
//

import Foundation

class Buffer {
    typealias Index = Rope.Index

    var contents: Rope

    convenience init() {
        self.init("")
    }

    init(_ string: String) {
        self.contents = Rope(string)
    }

    var data: Data {
        Data(contents)
    }

    var utf16Count: Int {
        contents.utf16Count
    }

    var lineCount: Int {
        contents.lines.count
    }

    var lines: Rope.LinesView {
        contents.lines
    }

    var documentRange: Range<Index> {
        contents.startIndex..<contents.endIndex
    }

    var startIndex: Index {
        contents.startIndex
    }

    var endIndex: Index {
        contents.endIndex
    }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        contents.index(i, offsetBy: distance)
    }

    func index(at offset: Int) -> Index {
        contents.index(startIndex, offsetBy: offset)
    }

    func attributedSubstring(for range: Range<Index>) -> NSAttributedString {
        NSAttributedString(string: String(contents[range]))
    }
}

extension Range where Bound == Buffer.Index {
    init?(_ range: NSRange, in buffer: Buffer) {
        self.init(range, in: buffer.contents)
    }
}

extension NSRange {
    init<R>(_ region: R, in buffer: Buffer) where R : RangeExpression, R.Bound == Buffer.Index {
        self.init(region, in: buffer.contents)
    }
}
