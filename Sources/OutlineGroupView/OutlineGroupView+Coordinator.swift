//
//  Coordinator.swift
//  OutlineGroupView
//
//  Created by lova on 2025/4/13.
//

import SwiftUI

// MARK: - 協調器

public extension OutlineGroupView {
    class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        private var parent: OutlineGroupView
        var data: [Item]
        var children: KeyPath<Item, [Item]?>
        var dragDropConfig: DragDropConfiguration<Item>?
        var selectionBinding: Binding<Set<Item.ID>>?

        init(
            _ parent: OutlineGroupView,
            data: [Item],
            children: KeyPath<Item, [Item]?>,
            selectionBinding: Binding<Set<Item.ID>>? = nil,
        ) {
            self.parent = parent
            self.data = data
            self.children = children
            self.selectionBinding = selectionBinding
        }

        // MARK: - NSOutlineViewDataSource

        public func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            if let item = item as? Item {
                return item[keyPath: children]?.count ?? 0
            } else {
                return data.count
            }
        }

        public func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            if let item = item as? Item {
                return item[keyPath: children]![index]
            } else {
                return data[index]
            }
        }

        public func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let item = item as? Item else { return false }
            return item[keyPath: children]?.isEmpty == false
        }

        // MARK: - NSOutlineViewDelegate

        public func outlineView(_: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
            guard let item = item as? Item else { return nil }

            // 創建一個包裝器來顯示 SwiftUI 內容
            let hostingView = NSHostingView(rootView: parent.rowContent(item))
            hostingView.translatesAutoresizingMaskIntoConstraints = false

            return hostingView
        }

        // MARK: - 選擇處理

        public func outlineViewSelectionDidChange(_ notification: Notification) {
            guard let outlineView = notification.object as? NSOutlineView else { return }

            // 獲取所有選中的項目
            let selectedItems = outlineView.selectedRowIndexes.compactMap { outlineView.item(atRow: $0) as? Item }

            // 更新綁定的選擇狀態
            if let selectionBinding = selectionBinding {
                let selectedIds = Set(selectedItems.map { $0.id })
                selectionBinding.wrappedValue = selectedIds
            }
        }

        // MARK: - 拖放支援

        public func outlineView(_: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
            guard let dragDropConfig = dragDropConfig,
                  let item = item as? Item else { return nil }

            let itemProvider = NSPasteboardItem()
            let itemId = String(describing: item.id)
            let data = try? JSONEncoder().encode(["id": itemId])
            itemProvider.setData(data ?? Foundation.Data(), forType: .data)
            return itemProvider
        }

        public func outlineView(_: NSOutlineView, validateDrop _: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
            guard let dragDropConfig = dragDropConfig else { return [] }

            let destination = item as? Item
            return dragDropConfig.validateDrop(destination, index) ? .move : []
        }

        public func outlineView(_: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
            guard let dragDropConfig = dragDropConfig,
                  let pasteboardData = info.draggingPasteboard.data(forType: .data),
                  let dict = try? JSONSerialization.jsonObject(with: pasteboardData) as? [String: String],
                  let idString = dict["id"] else { return false }

            // 嘗試從ID字符串找到對應項目
            let sourceItem = findItemByStringId(idString, in: data)
            guard let sourceItem = sourceItem else { return false }

            let destination = item as? Item
            return dragDropConfig.performDrop(sourceItem, destination, index)
        }

        // 通過ID字符串查找項目
        private func findItemByStringId(_ idString: String, in items: [Item]) -> Item? {
            for item in items {
                let itemIdString = String(describing: item.id)
                if itemIdString == idString {
                    return item
                }

                if let children = item[keyPath: children], let found = findItemByStringId(idString, in: children) {
                    return found
                }
            }
            return nil
        }

        private func findItem(with id: Item.ID, in items: [Item]) -> Item? {
            for item in items {
                if item.id == id {
                    return item
                }

                if let children = item[keyPath: children], let found = findItem(with: id, in: children) {
                    return found
                }
            }
            return nil
        }
    }
}
