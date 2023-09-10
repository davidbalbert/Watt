//
//  TreeSitter.swift
//  Watt
//
//  Created by David Albert on 9/7/23.
//

import Foundation
import TreeSitter

struct TreeSitterLanguage {
    public var tsLanguage: UnsafePointer<TSLanguage>
}

class TreeSitterParser {
    var tsParser: OpaquePointer // TSParser *

    convenience init?(language: TreeSitterLanguage) {
        self.init()

        guard (try? setLanguage(language)) != nil else {
            return nil
        }
    }

    init() {
        tsParser = ts_parser_new()
    }

    deinit {
        ts_parser_delete(tsParser)
    }
}

extension TreeSitterParser {
    enum ParserError: Error {
        case languageIncompatible
        case languageFailure
        case languageInvalid
        case unsupportedEncoding(String.Encoding)
    }

    public var language: TreeSitterLanguage? {
        get {
            return ts_parser_language(tsParser).map { TreeSitterLanguage(tsLanguage: $0) }
        }
    }

    func setLanguage(_ language: TreeSitterLanguage) throws {
        try setLanguage(language.tsLanguage)
    }

    public func setLanguage(_ language: UnsafePointer<TSLanguage>) throws {
        let success = ts_parser_set_language(tsParser, language)

        if success == false {
            throw ParserError.languageFailure
        }
    }
}

extension TreeSitterParser {
    public typealias ReadBlock = (Int, TSPoint) -> Substring?

    class Input {
        typealias Buffer = UnsafeMutableBufferPointer<Int8>

        let encoding: TSInputEncoding
        let readBlock: ReadBlock

        var _buffer: Buffer?
        var buffer: Buffer? {
            get {
                return _buffer
            }
            set {
                _buffer?.deallocate()
                _buffer = newValue
            }
        }

        init(encoding: TSInputEncoding, readBlock: @escaping ReadBlock) {
            self.encoding = encoding
            self.readBlock = readBlock
        }

        deinit {
            _buffer?.deallocate()
        }
    }

    public func parse(oldTree: TreeSitterTree?, encoding: TSInputEncoding, readBlock: @escaping ReadBlock) -> TreeSitterTree? {
        let input = Input(encoding: encoding, readBlock: readBlock)

        let tsInput = TSInput(
            payload: Unmanaged.passUnretained(input).toOpaque(),
            read: readFunction,
            encoding: encoding
        )

        guard let newTree = ts_parser_parse(tsParser, oldTree?.tsTree, tsInput) else {
            return nil
        }

        return TreeSitterTree(tsTree: newTree)
    }
}

fileprivate func readFunction(payload: UnsafeMutableRawPointer?, byteIndex: UInt32, position: TSPoint, bytesRead: UnsafeMutablePointer<UInt32>?) -> UnsafePointer<CChar>? {
    // get our self reference
    let input: TreeSitterParser.Input = Unmanaged.fromOpaque(payload!).takeUnretainedValue()

    guard let s = input.readBlock(Int(byteIndex), position) else {
        bytesRead?.pointee = 0
        return nil
    }

    // copy the data into an internally-managed buffer with a lifetime of input
    let buffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: s.utf8.count)
    let n = s.withExistingUTF8 { p in
        p.copyBytes(to: buffer)
    }
    precondition(n == s.utf8.count)

    input.buffer = buffer

    // return to the caller
    bytesRead?.pointee = UInt32(buffer.count)

    return UnsafePointer(buffer.baseAddress)
}

extension TreeSitterParser {
    func parse(_ rope: Rope, oldTree: TreeSitterTree?) -> TreeSitterTree? {
        parse(oldTree: oldTree, encoding: TSInputEncodingUTF8) { byteIndex, position in
            let i = rope.utf8.index(at: byteIndex)
            guard let (chunk, offset) = i.read() else {
                return nil
            }

            let si = chunk.string.utf8Index(at: offset)

            return chunk.string[si...]
        }
    }
}

class TreeSitterTree {
    var tsTree: OpaquePointer // TSTree *

    init(tsTree: OpaquePointer) {
        self.tsTree = tsTree
    }

    var root: TreeSitterNode {
        TreeSitterNode(tree: self, tsNode: ts_tree_root_node(tsTree))
    }
}

struct TreeSitterNode {
    var tree: TreeSitterTree
    var tsNode: TSNode

    init(tree: TreeSitterTree, tsNode: TSNode) {
        self.tree = tree
        self.tsNode = tsNode
    }
}

extension TreeSitterNode: CustomDebugStringConvertible {
    var debugDescription: String {
        let s = ts_node_string(tsNode)
        defer { free(s) }
        return String(cString: s!)
    }
}

struct TreeSitterQuery {
    var tsQuery: OpaquePointer // TSQuery *

    init(tsQuery: OpaquePointer) {
        self.tsQuery = tsQuery
    }
}