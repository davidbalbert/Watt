//
//  LRUCache.swift
//  Watt
//
//  Created by David Albert on 5/13/23.
//

import Foundation

struct LRUCache<Key, Value> where Key: Hashable {
    private class Node {
        var key: Key
        var value: Value
        var prev: Node?
        var next: Node?

        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }

    let capacity: Int
    private var nodes: [Key: Node]
    private var head: Node?

    private var tail: Node? {
        head?.prev
    }

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.nodes = Dictionary(minimumCapacity: self.capacity)
    }

    var count: Int {
        nodes.count
    }

    subscript(key: Key) -> Value? {
        mutating get {
            get(key)
        }
        set {
            if let value = newValue {
                set(key, value)
            } else if let node = nodes[key] {
                // if we assign nil, remove from the cache
                remove(node)
                nodes.removeValue(forKey: key)
            }
        }
    }

    mutating func removeAll() {
        nodes.removeAll(keepingCapacity: true)
        head = nil
    }

    mutating private func get(_ key: Key) -> Value? {
        guard let node = nodes[key] else {
            return nil
        }

        touch(node)
        return node.value
    }

    mutating private func set(_ key: Key, _ value: Value) {
        if let node = nodes[key] {
            node.value = value
            touch(node)
        } else {
            let node = Node(key: key, value: value)
            if nodes.count == capacity, let tail {
                nodes.removeValue(forKey: tail.key)
                remove(node)
            }

            add(node)
            nodes[key] = node
        }
    }

    mutating private func add(_ node: Node) {
        if let head, let tail {
            node.next = head
            node.prev = tail

            head.prev = node
            tail.next = node

            self.head = node
        } else {
            node.next = node
            node.prev = node
            head = node
        }
    }

    mutating private func remove(_ node: Node) {
        if node.next === node {
            // we're the only node
            assert(node === head)
            head = nil
        } else {
            node.prev?.next = node.next
            node.next?.prev = node.prev

            if head === node {
                head = node.next
            }
        }

        node.prev = nil
        node.next = nil
    }

    mutating private func touch(_ node: Node) {
        remove(node)
        add(node)
    }
}
