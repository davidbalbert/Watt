//
//  OutlineViewDiffableDataSource.swift
//  Watt
//
//  Created by David Albert on 1/9/24.
//

import Cocoa
import SwiftUI

import Tree

final class OutlineViewDiffableDataSource<Data>: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate where Data: RandomAccessCollection, Data.Element: Identifiable {
    let outlineView: NSOutlineView
    let delegate: NSOutlineViewDelegate?
    let cellProvider: (NSOutlineView, NSTableColumn, Data.Element) -> NSView
    var rowViewProvider: ((NSOutlineView, Data.Element) -> NSTableRowView)?

    var defaultRowAnimation: NSTableView.AnimationOptions = .effectFade

    private(set) var snapshot: Snapshot?

    init(_ outlineView: NSOutlineView, delegate: NSOutlineViewDelegate? = nil, cellProvider: @escaping (NSOutlineView, NSTableColumn, Data.Element) -> NSView) {
        self.outlineView = outlineView
        self.delegate = delegate
        self.cellProvider = cellProvider
        super.init()
        outlineView.dataSource = self
        outlineView.delegate = self
    }

    convenience init<Body>(_ outlineView: NSOutlineView, delegate: NSOutlineViewDelegate? = nil, @ViewBuilder cellProvider: @escaping (NSOutlineView, NSTableColumn, Data.Element) -> Body) where Body: View {
        self.init(outlineView, delegate: delegate) { outlineView, column, element in
            let rootView = cellProvider(outlineView, column, element)

            let hostingView: NSHostingView<Body>
            if let v = outlineView.makeView(withIdentifier: column.identifier, owner: nil) as? NSHostingView<Body> {
                hostingView = v
            } else {
                hostingView = NSHostingView(rootView: rootView)
                hostingView.identifier = column.identifier
            }

            hostingView.rootView = rootView
            hostingView.autoresizingMask = [.width, .height]

            let view = NSTableCellView()
            view.addSubview(hostingView)

            return view
        }
    }

    func id(for item: Any?) -> Data.Element.ID? {
        if let item {
            return (item as! Data.Element.ID?)
        } else {
            return nil
        }
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let snapshot else {
            return 0
        }
        return snapshot.childIds(of: id(for: item))?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let snapshot else {
            fatalError("unexpected call to outlineView(_:child:ofItem:) with no snapshot")
        }
        return snapshot.childId(atOffset: index, of: id(for: item))!
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let snapshot else {
            return false
        }
        return snapshot.childIds(of: id(for: item)) != nil
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let snapshot, let tableColumn else {
            return nil
        }
        return cellProvider(outlineView, tableColumn, snapshot[id(for: item)!]!)
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        guard let snapshot else {
            return nil
        }
        return rowViewProvider?(outlineView, snapshot[id(for: item)!]!)
    }
}

extension TreeNode {
    init<Data>(_ element: Data.Element, children: KeyPath<Data.Element, Data?>) where Data: RandomAccessCollection, Data.Element: Identifiable, Value == Data.Element.ID {
        self.init(element.id, children: element[keyPath: children]?.map { TreeNode($0, children: children) } ?? [])
    }
}

extension TreeList {
    init<Data>(_ data: Data, children: KeyPath<Data.Element, Data?>) where Data: RandomAccessCollection, Data.Element: Identifiable, Value == Data.Element.ID {
        self.init(data.map { TreeNode($0, children: children) })
    }
}

extension OutlineViewDiffableDataSource {
    struct Snapshot {
        let ids: TreeList<Data.Element.ID>
        let children: KeyPath<Data.Element, Data?>
        let index: [Data.Element.ID: Data.Element]

        init(_ data: Data, children: KeyPath<Data.Element, Data?>) {
            self.ids = TreeList(data, children: children)
            self.children = children
            self.index = Dictionary(data.map { ($0.id, $0) }) { left, right in
                print("duplicate id=\(left.id) for values left=\(left) right=\(right). Using left=\(left)")
                return left
            }
        }

        subscript(id: Data.Element.ID) -> Data.Element? {
            index[id]
        }

        func childId(atOffset offset: Int, of id: Data.Element.ID?) -> Data.Element.ID? {
            childIds(of: id)?[offset]
        }

        func childIds(of id: Data.Element.ID?) -> [Data.Element.ID]? {
            if let id {
                return index[id]?[keyPath: children]?.map(\.id)
            } else {
                return ids.nodes.map(\.value)
            }
        }

        func difference(from other: Snapshot) -> Difference {
            Difference(treeDiff: ids.difference(from: other.ids).inferringMoves())
        }
    }
}

extension OutlineViewDiffableDataSource {
    struct Difference {
        typealias Change = TreeDifference<Data.Element.ID>.Change

        let treeDiff: TreeDifference<Data.Element.ID>

        var isSingleMove: Bool {
            guard changes.count == 2 else { return false }
            guard case let .remove(_, _, insertPosition) = changes.first else { return false }
            return insertPosition != nil
        }

        var changes: [Change] {
            treeDiff.changes
        }
    }
}

extension OutlineViewDiffableDataSource {
    func apply(_ snapshot: Snapshot, animatingDifferences: Bool = true) {
        let new = snapshot
        
        guard let old = self.snapshot, animatingDifferences else {
            self.snapshot = new
            outlineView.reloadData()
            return
        }

        let diff = new.difference(from: old)
        self.snapshot = new

        outlineView.beginUpdates()
        if diff.isSingleMove, case let .insert(newIndex, _, .some(oldIndex)) = diff.changes.last {
            outlineView.moveItem(at: oldIndex.offset, inParent: oldIndex.parent, to: newIndex.offset, inParent: newIndex.parent)
        } else {
            for change in diff.changes {
                switch change {
                case let .insert(newIndex, _, _):
                    outlineView.insertItems(at: [newIndex.offset], inParent: newIndex.parent, withAnimation: defaultRowAnimation)
                case let .remove(newIndex, _, _):
                    outlineView.removeItems(at: [newIndex.offset], inParent: newIndex.parent, withAnimation: defaultRowAnimation)
                }
            }
        }
        outlineView.endUpdates()
    }
}
