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
    let delegate: Delegate
    let cellProvider: (NSOutlineView, NSTableColumn, Data.Element) -> NSView
    var rowViewProvider: ((NSOutlineView, Data.Element) -> NSTableRowView)?
    var loadChildren: ((Data.Element) -> OutlineViewSnapshot<Data>?)?

    var insertRowAnimation: NSTableView.AnimationOptions = [.effectFade, .slideDown]
    var removeRowAnimation: NSTableView.AnimationOptions = [.effectFade, .slideUp]

    private(set) var snapshot: OutlineViewSnapshot<Data>?

    init(_ outlineView: NSOutlineView, delegate: NSOutlineViewDelegate? = nil, cellProvider: @escaping (NSOutlineView, NSTableColumn, Data.Element) -> NSView) {
        self.outlineView = outlineView
        self.delegate = Delegate(target: delegate ?? EmptyOutlineViewDelegate())
        self.cellProvider = cellProvider
        super.init()

        self.delegate.dataSource = self
        self.outlineView.dataSource = self
        self.outlineView.delegate = self.delegate
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

    private func id(from item: Any?) -> Data.Element.ID? {
        if let item {
            return (item as! Data.Element.ID?)
        } else {
            return nil
        }
    }

    func element(for id: Data.Element.ID) -> Data.Element? {
        snapshot?[id]
    }

    func loadChildrenIfNecessary(for id: Data.Element.ID?) {
        guard let lazyDataLoader = loadChildren, let id, let snapshot, let element = snapshot[id] else {
            return
        }

        if let newSnapshot = lazyDataLoader(element) {
            // Snapshot should be the same except for the new data, so no need to diff.
            self.snapshot = newSnapshot
        }
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let id = id(from: item)
        loadChildrenIfNecessary(for: id)

        guard let snapshot else {
            return 0
        }
        return snapshot.childIds(of: id)?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let id = id(from: item)
        loadChildrenIfNecessary(for: id)

        guard let snapshot else {
            fatalError("unexpected call to outlineView(_:child:ofItem:) with no snapshot")
        }

        return snapshot.childId(atOffset: index, of: id)!
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let snapshot else {
            return false
        }
        return snapshot.childIds(of: id(from: item)) != nil
    }
}

extension OutlineViewDiffableDataSource {
    class EmptyOutlineViewDelegate: NSObject, NSOutlineViewDelegate {}

    class Delegate: SimpleProxy, NSOutlineViewDelegate {
        weak var dataSource: OutlineViewDiffableDataSource?

        init(target: NSOutlineViewDelegate) {
            super.init(target: target)
        }

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let dataSource, let snapshot = dataSource.snapshot, let tableColumn else {
                return nil
            }
            return dataSource.cellProvider(outlineView, tableColumn, snapshot[dataSource.id(from: item)!]!)
        }

        func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
            guard let dataSource, let snapshot = dataSource.snapshot else {
                return nil
            }
            return dataSource.rowViewProvider?(outlineView, snapshot[dataSource.id(from: item)!]!)
        }
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

struct OutlineViewSnapshot<Data> where Data: RandomAccessCollection, Data.Element: Identifiable {
    let ids: TreeList<Data.Element.ID>
    let children: KeyPath<Data.Element, Data?>
    let index: [Data.Element.ID: Data.Element]

    init(_ data: Data, children: KeyPath<Data.Element, Data?>) {
        self.ids = TreeList(data, children: children)
        self.children = children

        var index: [Data.Element.ID: Data.Element] = [:]
        var pending: [Data.Element] = Array(data)
        while !pending.isEmpty {
            let element = pending.removeFirst()
            index[element.id] = element
            if let children = element[keyPath: children] {
                pending.append(contentsOf: children)
            }
        }

        self.index = index
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

    func difference(from other: Self) -> Difference {
        Difference(treeDiff: ids.difference(from: other.ids).inferringMoves())
    }
}

extension OutlineViewSnapshot where Data: RangeReplaceableCollection {
    init(_ root: Data.Element, children: KeyPath<Data.Element, Data?>) {
        self.init(Data([root]), children: children)
    }
}

extension OutlineViewSnapshot {
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
    func apply(_ snapshot: OutlineViewSnapshot<Data>, animatingDifferences: Bool = true) {
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
                    outlineView.insertItems(at: [newIndex.offset], inParent: newIndex.parent, withAnimation: insertRowAnimation)
                case let .remove(newIndex, _, _):
                    outlineView.removeItems(at: [newIndex.offset], inParent: newIndex.parent, withAnimation: removeRowAnimation)
                }
            }
        }
        outlineView.endUpdates()
    }
}
