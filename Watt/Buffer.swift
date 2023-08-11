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
    var layoutManagers: [LayoutManager]

    convenience init() {
        self.init("")
    }

    init(_ string: String) {
        self.contents = Rope(string)
        self.layoutManagers = []
    }

    var data: Data {
        Data(contents)
    }

    var utf8: Rope.UTF8View {
        contents.utf8
    }

    var utf16: Rope.UTF16View {
        contents.utf16
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

    subscript(i: Index) -> Character {
        contents[i]
    }

    func index(before i: Index) -> Index {
        contents.index(before: i)
    }

    func index(after i: Index) -> Index {
        contents.index(after: i)
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

    func addLayoutManager(_ layoutManager: LayoutManager) {
        if layoutManagers.contains(where: { $0 === layoutManager }) {
            return
        }

        layoutManagers.append(layoutManager)
        layoutManager.buffer = self
    }

    func removeLayoutManager(_ layoutManager: LayoutManager) {
        layoutManagers.removeAll { $0 === layoutManager }
        layoutManager.buffer = nil
   }

    func replaceSubrange(_ subrange: Range<Index>, with attrString: NSAttributedString) {
        let rope = Rope(attrString.string)
        let range = subrange.lowerBound.position..<subrange.upperBound.position

        var b = Rope.DeltaBuilder(contents.count)
        b.replace(range, with: rope)
        let delta = b.build()

        let old = contents
        contents = contents.applying(delta: delta)

        for layoutManager in layoutManagers {
            layoutManager.bufferContentsDidChange(from: old, to: contents, delta: delta)
        }
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
