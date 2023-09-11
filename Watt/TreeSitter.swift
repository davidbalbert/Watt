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

    func query(contentsOf url: URL) throws -> TreeSitterQuery {
        let data = try Data(contentsOf: url)
        return try TreeSitterQuery(language: self, data: data)
    }
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

final class TreeSitterQuery: Sendable {
    public enum QueryError: Error {
        case none
        case syntax(UInt32)
        case nodeType(UInt32)
        case field(UInt32)
        case capture(UInt32)
        case structure(UInt32)
        case unknown(UInt32)

        init(offset: UInt32, internalError: TSQueryError) {
            switch internalError {
            case TSQueryErrorNone:
                self = .none
            case TSQueryErrorSyntax:
                self = .syntax(offset)
            case TSQueryErrorNodeType:
                self = .nodeType(offset)
            case TSQueryErrorField:
                self = .field(offset)
            case TSQueryErrorCapture:
                self = .capture(offset)
            case TSQueryErrorStructure:
                self = .structure(offset)
            default:
                self = .unknown(offset)
            }
        }
    }

    let tsQuery: OpaquePointer
//    let predicateList: [[Predicate]]

    /// Construct a query object from scm data
    ///
    /// This operation has do to a lot of work, especially if any
    /// patterns contain predicates. You should expect it will
    /// be expensive.
    init(language: TreeSitterLanguage, data: Data) throws {
        let dataLength = data.count
        var errorOffset: UInt32 = 0
        var queryError: TSQueryError = TSQueryErrorNone

        let tsQuery = data.withUnsafeBytes { (p: UnsafeRawBufferPointer) -> OpaquePointer? in
            p.withMemoryRebound(to: CChar.self) { p in
                guard let addr = p.baseAddress else {
                    return nil
                }

                return ts_query_new(language.tsLanguage,
                                    addr,
                                    UInt32(dataLength),
                                    &errorOffset,
                                    &queryError)
            }
        }

        guard let tsQuery else {
            throw QueryError(offset: errorOffset, internalError: queryError)
        }

        self.tsQuery = tsQuery
        // self.predicateList = try PredicateParser().predicates(in: queryPtr)
    }

    deinit {
        ts_query_delete(tsQuery)
    }

    var patternCount: Int {
        return Int(ts_query_pattern_count(tsQuery))
    }

    var captureCount: Int {
        return Int(ts_query_capture_count(tsQuery))
    }

    var stringCount: Int {
        return Int(ts_query_string_count(tsQuery))
    }

	/// Run a query
	///
	/// Note that both the node **and** the tree is is part of
	/// must remain valid as long as the query is being used.
	///
	/// - Parameter node: the root node for the query
	/// - Parameter tree: keep an optional reference to the tree
    // public func execute(node: Node, in tree: Tree? = nil) -> QueryCursor {
    //     let cursor = QueryCursor()

    //     cursor.execute(query: self, node: node, in: tree)

    //     return cursor
    // }

    // public func captureName(for id: Int) -> String? {
    //     var length: UInt32 = 0

    //     guard let cStr = ts_query_capture_name_for_id(internalQuery, UInt32(id), &length) else {
    //         return nil
    //     }

    //     return String(cString: cStr)
    // }

    // public func stringName(for id: Int) -> String? {
    //     var length: UInt32 = 0

    //     guard let cStr = ts_query_string_value_for_id(internalQuery, UInt32(id), &length) else {
    //         return nil
    //     }

    //     return String(cString: cStr)
    // }

    // public func predicates(for patternIndex: Int) -> [Predicate] {
    //     return predicateList[patternIndex]
    // }

    // public var hasPredicates: Bool {
    //     for i in 0..<patternCount {
    //         if predicates(for: i).isEmpty == false {
    //             return true
    //         }
    //     }

    //     return false
    // }
}
