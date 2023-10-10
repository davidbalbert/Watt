//
//  TreeSitter.swift
//  Watt
//
//  Created by David Albert on 9/7/23.
//

import Foundation
import TreeSitter

final class TreeSitterLanguage {
    let languagePointer: UnsafePointer<TSLanguage>

    init(_ language: UnsafePointer<TSLanguage>) {
        self.languagePointer = language
    }

    func query(contentsOf url: URL) throws -> TreeSitterQuery {
        let data = try Data(contentsOf: url)
        return try TreeSitterQuery(data: data, language: languagePointer)
    }
}

protocol TreeSitterParserDelegate: AnyObject {
    func parser(_ parser: TreeSitterParser, readSubstringStartingAt byteIndex: Int) -> Substring?
}

enum TreeSitterInputEncoding {
    case utf8
    case utf16

    var tsInputEncoding: TSInputEncoding {
        switch self {
        case .utf8:
            return TSInputEncodingUTF8
        case .utf16:
            return TSInputEncodingUTF16
        }
    }
}

final class TreeSitterParser {
     enum ParserError: Error {
         case languageIncompatible
     }

    private var pointer: OpaquePointer // TSParser *

    weak var delegate: TreeSitterParserDelegate?
    let encoding: TSInputEncoding

    var language: TreeSitterLanguage {
        // TSParsers can be created without an associated
        // language, but we don't allow that, so it's ok
        // to force unwrap.
        TreeSitterLanguage(ts_parser_language(pointer)!)
    }

    init(language: TreeSitterLanguage, encoding: TreeSitterInputEncoding) throws {
        self.encoding = encoding.tsInputEncoding
        self.pointer = ts_parser_new()

        let success = ts_parser_set_language(self.pointer, language.languagePointer)

        if success == false {
            throw ParserError.languageIncompatible
        }
    }

    deinit {
        ts_parser_delete(pointer)
    }

    func parse(oldTree: TreeSitterTree? = nil) -> TreeSitterTree? {
        let input = TreeSitterTextInput() { [weak self] byteIndex, _ in
            if let self = self {
                return self.delegate?.parser(self, readSubstringStartingAt: byteIndex)
            } else {
                return nil
            }
        }
        // TODO: this might not be necessary. I know that Swift has been
        // changing rules about how long liftimes last. Look into it.
        defer { withExtendedLifetime(input) {} }

        let tsInput = TSInput(
            payload: Unmanaged.passUnretained(input).toOpaque(),
            read: { payload, byteIndex, position, bytesRead in
                let input: TreeSitterTextInput = Unmanaged.fromOpaque(payload!).takeUnretainedValue()

                guard let s = input.callback(Int(byteIndex), TreeSitterTextPoint(position)) else {
                    bytesRead?.pointee = 0
                    return nil
                }

                // copy the data into an internally-managed buffer with a lifetime of input
                let buf = UnsafeMutableBufferPointer<CChar>.allocate(capacity: s.utf8.count)
                let n = s.withExistingUTF8 { p in
                    p.copyBytes(to: buf)
                }
                precondition(n == s.utf8.count)
                input.buf = buf

                bytesRead?.pointee = UInt32(buf.count)
                return UnsafePointer(buf.baseAddress)
            },
            encoding: encoding
        )

        guard let newTree = ts_parser_parse(pointer, oldTree?.pointer, tsInput) else {
            return nil
        }

        return TreeSitterTree(newTree)
    }
}

typealias TreeSitterReadCallback = (_ byteIndex: Int, _ position: TreeSitterTextPoint) -> Substring?

// TODO: can this be made to work with UTF-16 encoded text as well? Would make it easier to
// contribute changes back to SwiftTreeSitter/Runestone.
//
// This seems like it might be unlikely without making two copies until Swift adds
// BufferViews – we return a Substring from TreeSitterReadCallback so that we only
// do one copy, which happens inside read(). But AFAIK, there's no way to check if
// a Substring is a bridged NSString, which AFAIK is the only time we'd get UTF-16
// bytes. The real win would be to have TreeSitterReadCallback return some sort of
// non-string thing. Either Data, a BufferView, or an UnsafeBufferPointer. Data would
// require two copies, and I think UnsafeBufferPointer isn't doable with Swift's
// current ARC semantics. Fingers crossed for BufferView.
final class TreeSitterTextInput {
    let callback: TreeSitterReadCallback

    var _buf: UnsafeMutableBufferPointer<Int8>?
    var buf: UnsafeMutableBufferPointer<Int8>? {
        get {
            return _buf
        }
        set {
            _buf?.deallocate()
            _buf = newValue
        }
    }

    deinit {
        buf?.deallocate()
    }

    init(callback: @escaping TreeSitterReadCallback) {
        self.callback = callback
    }
}

struct TreeSitterInputEdit {
    let startByte: Int
    let oldEndByte: Int
    let newEndByte: Int
    let startPoint: TreeSitterTextPoint
    let oldEndPoint: TreeSitterTextPoint
    let newEndPoint: TreeSitterTextPoint

    init(startByte: Int,
         oldEndByte: Int,
         newEndByte: Int,
         startPoint: TreeSitterTextPoint,
         oldEndPoint: TreeSitterTextPoint,
         newEndPoint: TreeSitterTextPoint) {
        self.startByte = startByte
        self.oldEndByte = oldEndByte
        self.newEndByte = newEndByte
        self.startPoint = startPoint
        self.oldEndPoint = oldEndPoint
        self.newEndPoint = newEndPoint
    }
}

extension TreeSitterInputEdit: CustomDebugStringConvertible {
    var debugDescription: String {
        "[TreeSitterInputEdit startByte=\(startByte) oldEndByte=\(oldEndByte) newEndByte=\(newEndByte)"
            + " startPoint=\(startPoint) oldEndPoint=\(oldEndPoint) newEndPoint=\(newEndPoint)]"
    }
}

extension TSInputEdit {
    init(_ inputEdit: TreeSitterInputEdit) {
        self.init(start_byte: UInt32(inputEdit.startByte),
                  old_end_byte: UInt32(inputEdit.oldEndByte),
                  new_end_byte: UInt32(inputEdit.newEndByte),
                  start_point: inputEdit.startPoint.rawValue,
                  old_end_point: inputEdit.oldEndPoint.rawValue,
                  new_end_point: inputEdit.newEndPoint.rawValue)
    }
}

// TODO: turn this into a copy-on-write struct
final class TreeSitterTree {
    let pointer: OpaquePointer // TSTree *

    var root: TreeSitterNode {
        TreeSitterNode(tree: self, node: ts_tree_root_node(pointer))
    }

    init(_ tree: OpaquePointer) {
        self.pointer = tree
    }

    deinit {
        ts_tree_delete(pointer)
    }

    func apply(_ inputEdit: TreeSitterInputEdit) {
        withUnsafePointer(to: TSInputEdit(inputEdit)) { inputEditPointer in
            ts_tree_edit(pointer, inputEditPointer)
        }
    }

    func rangesChanged(comparingTo otherTree: TreeSitterTree) -> [TreeSitterTextRange] {
        var count: UInt32 = 0
        let ptr = ts_tree_get_changed_ranges(pointer, otherTree.pointer, &count)
defer { free(ptr) }

        return UnsafeBufferPointer(start: ptr, count: Int(count)).map { range in
            let startPoint = TreeSitterTextPoint(range.start_point)
            let endPoint = TreeSitterTextPoint(range.end_point)
            let startByte = range.start_byte
            let endByte = range.end_byte
            return TreeSitterTextRange(startPoint: startPoint, endPoint: endPoint, startByte: Int(startByte), endByte: Int(endByte))
        }
    }
}

extension TreeSitterTree: CustomDebugStringConvertible {
    var debugDescription: String {
        "[TreeSitterTree rootNode=\(root)]"
    }
}

final class TreeSitterNode {
    // Make sure tree doesn't get deallocated before node.
    let tree: TreeSitterTree
    let rawValue: TSNode


    init(tree: TreeSitterTree, node: TSNode) {
        self.tree = tree
        self.rawValue = node
    }

    var startByte: Int {
        Int(ts_node_start_byte(rawValue))
    }

    var endByte: Int {
        Int(ts_node_end_byte(rawValue))
    }

    var range: Range<Int> {
        startByte..<endByte
    }

    var startPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(ts_node_start_point(rawValue))
    }

    var endPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(ts_node_end_point(rawValue))
    }
}

extension TreeSitterNode: CustomDebugStringConvertible {
    var debugDescription: String {
        let s = ts_node_string(rawValue)!
        defer { free(s) }
        return String(cString: s)
    }
}

extension TreeSitterNode: CustomStringConvertible {
    var description: String {
        "[TreeSitterNode startByte=\(startByte) endByte=\(endByte) startPoint=\(startPoint) endPoint=\(endPoint)]"
    }
}

struct TreeSitterTextPoint {
    var row: Int {
        Int(rawValue.row)
    }
    var column: Int {
        Int(rawValue.column)
    }

    let rawValue: TSPoint

    init(_ point: TSPoint) {
        self.rawValue = point
    }

    init(row: Int, column: Int) {
        self.rawValue = TSPoint(row: UInt32(row), column: UInt32(column))
    }
}

extension TreeSitterTextPoint: CustomDebugStringConvertible {
    var debugDescription: String {
        "[TreeSitterTextPoint row=\(row) column=\(column)]"
    }
}

struct TreeSitterTextRange {
    let rawValue: TSRange

    var startPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(rawValue.start_point)
    }
    var endPoint: TreeSitterTextPoint {
        TreeSitterTextPoint(rawValue.end_point)
    }
    var startByte: Int {
        Int(rawValue.start_byte)
    }
    var endByte: Int {
        Int(rawValue.end_byte)
    }

    init(startPoint: TreeSitterTextPoint, endPoint: TreeSitterTextPoint, startByte: Int, endByte: Int) {
        self.rawValue = TSRange(
            start_point: startPoint.rawValue,
            end_point: endPoint.rawValue,
            start_byte: UInt32(startByte),
            end_byte: UInt32(endByte))
    }
}

extension TreeSitterTextRange: CustomDebugStringConvertible {
    var debugDescription: String {
        "[TreeSitterTextRange startByte=\(startByte) endByte=\(endByte) startPoint=\(startPoint) endPoint=\(endPoint)]"
    }
}

struct TreeSitterPredicate {
    enum Step {
        case capture(UInt32)
        case string(String)

        var isCapture: Bool {
            switch self {
            case .capture:
                return true
            case .string:
                return false
            }
        }

        var isString: Bool {
            switch self {
            case .capture:
                return false
            case .string:
                return true
            }
        }
    }

    enum Name: String {
        case equal = "eq?"
        case notEqual = "not-eq?"
        case anyEqual = "any-eq?"
        case anyNotEqual = "any-not-eq?"
        case match = "match?"
        case notMatch = "not-match?"
        case anyMatch = "any-match?"
        case anyNotMatch = "any-not-match?"
        case anyOf = "any-of?"
        case notAnyOf = "not-any-of?"
        case `set` = "set!"
    }

    var name: Name
    let params: [Step]

    init(steps: [Step]) {
        guard case .string(let s) = steps.first else {
            preconditionFailure("first step must be a string")
        }

        guard let name = Name(rawValue: s) else {
            preconditionFailure("\(s) is not a valid precondition name")
        }

        self.name = name
        self.params = Array(steps[1...])
    }
}

extension TreeSitterPredicate: CustomDebugStringConvertible {
    var debugDescription: String {
        "[TreeSitterPredicate name=\(name) params=\(params)]"
    }
}

extension TreeSitterPredicate.Step: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .capture(let id):
            return "[TreeSitterPredicate.Step capture=\(id)]"
        case .string(let string):
            return "[TreeSitterPredicate.Step string=\(string)]"
        }
    }
}

enum TreeSitterQueryError: Error {
    case syntax(offset: UInt32)
    case nodeType(offset: UInt32)
    case field(offset: UInt32)
    case capture(offset: UInt32)
    case structure(offset: UInt32)
    case unknown
}

final class TreeSitterQuery {
    let pointer: OpaquePointer

    let language: UnsafePointer<TSLanguage>

    private var patternCount: UInt32 {
        ts_query_pattern_count(pointer)
    }

    init(data: Data, language: UnsafePointer<TSLanguage>) throws {
        var errorOffset: UInt32 = 0
        var errorType: TSQueryError = TSQueryErrorNone

        let pointer = data.withUnsafeBytes { (p: UnsafeRawBufferPointer) -> OpaquePointer? in
            p.withMemoryRebound(to: CChar.self) { p in
                guard let addr = p.baseAddress else {
                    return nil
                }

                // TODO: check the return type of ts_query_new. I'm curious to see if it's optional or not.
                return ts_query_new(language, addr, UInt32(data.count), &errorOffset, &errorType)
            }
        }

        switch errorType.rawValue {
        case 1:
            throw TreeSitterQueryError.syntax(offset: errorOffset)
        case 2:
            throw TreeSitterQueryError.nodeType(offset: errorOffset)
        case 3:
            throw TreeSitterQueryError.field(offset: errorOffset)
        case 4:
            throw TreeSitterQueryError.capture(offset: errorOffset)
        case 5:
            throw TreeSitterQueryError.structure(offset: errorOffset)
        default:
            if let pointer = pointer {
                self.language = language
                self.pointer = pointer
            } else {
                throw TreeSitterQueryError.unknown
            }
        }
    }

    deinit {
        ts_query_delete(pointer)
    }

    func stringValue(forId id: UInt32) -> String {
        var length: UInt32 = 0
        let p = ts_query_string_value_for_id(pointer, id, &length)!
        return String(bytes: p, count: Int(length), encoding: .utf8)!
    }

    func captureName(forId id: UInt32) -> String {
        var length: UInt32 = 0
        let p = ts_query_capture_name_for_id(pointer, id, &length)!
        return String(bytes: p, count: Int(length), encoding: .utf8)!
    }

    func predicates(forPatternIndex index: UInt32) -> [TreeSitterPredicate] {
        var stepCount: UInt32 = 0
        guard let p = ts_query_predicates_for_pattern(pointer, index, &stepCount) else {
            return []
        }

        let buf = UnsafeBufferPointer<TSQueryPredicateStep>(start: p, count: Int(stepCount))

        var predicates: [TreeSitterPredicate] = []
        var steps: [TreeSitterPredicate.Step] = []

        for rawStep in buf {
            if rawStep.type == TSQueryPredicateStepTypeCapture {
                steps.append(.capture(rawStep.value_id))
            } else if rawStep.type == TSQueryPredicateStepTypeString {
                steps.append(.string(stringValue(forId: rawStep.value_id)))
            } else if rawStep.type == TSQueryPredicateStepTypeDone {
                let predicate = TreeSitterPredicate(steps: steps)
                predicates.append(predicate)
                steps = []
            }
        }

        assert(steps.count == 0)

        return predicates
    }
}

struct TreeSitterPredicatesEvaluator {
    let match: TreeSitterQueryMatch
    // byte range to string
    let readString: (Range<Int>) -> String

    init(match: TreeSitterQueryMatch, readStringUsing block: @escaping (Range<Int>) -> String) {
        self.match = match
        self.readString = block
    }

    func evaluatePredicates(in capture: TreeSitterCapture) -> Bool {
        return capture.predicates.allSatisfy { predicate in
            switch predicate.name {
            case .equal:
                precondition(predicate.params.count == 2, "#eq? must have 2 params")
                let a = predicate.params[0]
                let b = predicate.params[1]

                return evalParam(a) == evalParam(b)
            case .notEqual:
                precondition(predicate.params.count == 2, "#not-eq? must have 2 params")
                let a = predicate.params[0]
                let b = predicate.params[1]

                return evalParam(a) != evalParam(b)
            case .anyEqual:
                fatalError("any-eq? not implemented")
            case .anyNotEqual:
                fatalError("any-not-eq? not implemented")
            case .match:
                precondition(predicate.params.count == 2, "#match? must have 2 params")
                let a = predicate.params[0]
                let b = predicate.params[1]

                precondition(a.isCapture, "#match? first param must be a capture")
                precondition(b.isString, "#match? second param must be a string")

                let val = evalParam(a)
                let pattern = evalParam(b)

                guard let regex = try? Regex(pattern) else {
                    preconditionFailure("invalid regex: \(pattern)")
                }

                return (try? regex.firstMatch(in: val)) != nil
            case .notMatch:
                precondition(predicate.params.count == 2, "#match? must have 2 params")
                let a = predicate.params[0]
                let b = predicate.params[1]

                precondition(a.isCapture, "#match? first param must be a capture")
                precondition(b.isString, "#match? second param must be a string")

                let val = evalParam(a)
                let pattern = evalParam(b)

                guard let regex = try? Regex(pattern) else {
                    preconditionFailure("invalid regex: \(pattern)")
                }

                return (try? regex.firstMatch(in: val)) == nil
            case .anyMatch:
                fatalError("any-match? not implemented")
            case .anyNotMatch:
                fatalError("any-not-match? not implemented")
            case .anyOf:
                precondition(predicate.params.count >= 2, "#any-of? must have at least 2 params")
                let a = predicate.params[0]
                let rest = predicate.params[1...]

                precondition(a.isCapture, "#any-of? first param must be a capture")
                precondition(rest.allSatisfy { $0.isString }, "#any-of? remaining params must be strings")

                let val = evalParam(a)
                return rest.contains { evalParam($0) == val }
            case .notAnyOf:
                precondition(predicate.params.count >= 2, "#any-of? must have at least 2 params")
                let a = predicate.params[0]
                let rest = predicate.params[1...]

                precondition(a.isCapture, "#any-of? first param must be a capture")
                precondition(rest.allSatisfy { $0.isString }, "#any-of? remaining params must be strings")

                let val = evalParam(a)
                return !rest.contains { evalParam($0) == val }
            case .set:
                fatalError("set! not implemented")
            }
        }
    }

    func evalParam(_ step: TreeSitterPredicate.Step) -> String {
        switch step {
        case .capture(let id):
            return readString(match.capture(forId: id).range)
        case .string(let string):
            return string
        }
    }
}

final class TreeSitterQueryCursor {
    let pointer: OpaquePointer
    let query: TreeSitterQuery
    let tree: TreeSitterTree
    var didExec: Bool

    // byte range to string
    let readString: (Range<Int>) -> String

    init(query: TreeSitterQuery, tree: TreeSitterTree, readStringUsing block: @escaping (Range<Int>) -> String) {
        self.pointer = ts_query_cursor_new()
        self.query = query
        self.tree = tree
        self.didExec = false
        self.readString = block
    }

    func executeIfNecessary() {
        if !didExec {
            ts_query_cursor_exec(pointer, query.pointer, tree.root.rawValue)
            didExec = true
        }
    }

    func reset() {
        didExec = false
    }

    deinit {
        ts_query_cursor_delete(pointer)
    }
}

extension TreeSitterQueryCursor {
    // Returns all non-empty captures that match their predicates. If
    // a range is matched by multiple patterns, the pattern closer to
    // the top of the query is selected
    func validCaptures() -> [TreeSitterCapture] {
        reset()

        var seen = Set<Range<Int>>()
        let matches = Array(matches)

        var captures = matches.flatMap { match in            
            match.captures.compactMap { capture in
                if !capture.range.isEmpty {
                    return (patternIndex: match.patternIndex, capture: capture)
                } else {
                    return nil
                }
            }
        }

        captures.sort { a, b in
            a.patternIndex < b.patternIndex
        }

        var result: [TreeSitterCapture] = []
        for (_, capture) in captures {
            if !seen.contains(capture.range) {
                result.append(capture)
                seen.insert(capture.range)
            }
        }

        // Not technically necessary, but it's easier if the tokens are returned in order
        result.sort { $0.range.lowerBound < $1.range.lowerBound }

        return result
    }
}

extension TreeSitterQueryCursor {
    // All matches, with all captures, including those that don't match their predicates
    struct RawMatches {
        var cursor: TreeSitterQueryCursor
    }

    var rawMatches: RawMatches {
        RawMatches(cursor: self)
    }
}

extension TreeSitterQueryCursor.RawMatches: Sequence {
    struct Iterator: IteratorProtocol {
        let cursor: TreeSitterQueryCursor
        var match: TSQueryMatch

        init(cursor: TreeSitterQueryCursor) {
            self.cursor = cursor
            self.match = TSQueryMatch(id: 0, pattern_index: 0, capture_count: 0, captures: nil)
        }

        mutating func next() -> TreeSitterQueryMatch? {
            cursor.executeIfNecessary()

            guard ts_query_cursor_next_match(cursor.pointer, &match) else {
                return nil
            }

            let buf = UnsafeBufferPointer<TSQueryCapture>(start: match.captures, count: Int(match.capture_count))
            let captures = buf.map { capture in
                let node = TreeSitterNode(tree: cursor.tree, node: capture.node)
                let name = cursor.query.captureName(forId: capture.index)
                let predicates = cursor.query.predicates(forPatternIndex: UInt32(match.pattern_index))
                return TreeSitterCapture(node: node, index: capture.index, name: name, predicates: predicates)
            }

            return TreeSitterQueryMatch(patternIndex: Int(match.pattern_index), captures: captures)
        }
    }

    func makeIterator() -> Iterator {
        Iterator(cursor: cursor)
    }
}

extension TreeSitterQueryCursor {
    // All matches, only including captures that match their predicates
    struct Matches {
        var cursor: TreeSitterQueryCursor
    }

    var matches: Matches {
        Matches(cursor: self)
    }
}

extension TreeSitterQueryCursor.Matches: Sequence {
    struct Iterator: IteratorProtocol {
        let cursor: TreeSitterQueryCursor
        var iter: TreeSitterQueryCursor.RawMatches.Iterator

        mutating func next() -> TreeSitterQueryMatch? {
            guard let match = iter.next() else {
                return nil
            }

            let evaluator = TreeSitterPredicatesEvaluator(match: match, readStringUsing: cursor.readString)
            let captures = match.captures.filter { evaluator.evaluatePredicates(in: $0) }

            return TreeSitterQueryMatch(patternIndex: match.patternIndex, captures: captures)
        }
    }

    func makeIterator() -> Iterator {
        Iterator(cursor: cursor, iter: cursor.rawMatches.makeIterator())
    }
}

struct TreeSitterQueryMatch {
    let patternIndex: Int
    let captures: [TreeSitterCapture]

    func capture(forId id: UInt32) -> TreeSitterCapture {
        captures.first { $0.index == id }!
    }
}

struct TreeSitterCapture {
    let node: TreeSitterNode
    let index: UInt32
    let name: String
    let predicates: [TreeSitterPredicate]

    init(node: TreeSitterNode, index: UInt32, name: String, predicates: [TreeSitterPredicate]) {
        self.node = node
        self.index = index
        self.name = name
        self.predicates = predicates
    }

    var range: Range<Int> {
        node.range
    }
}

extension TreeSitterCapture: CustomDebugStringConvertible {
    var debugDescription: String {
        "[TreeSitterCapture range=\(range) name=\(name)]"
    }
}
