// The Swift Programming Language
// https://docs.swift.org/swift-book

import AppKit
import Foundation
import SwiftUI

/// 可拖放的大綱視圖，用於替代原生的 OutlineGroup
/// 基於 NSOutlineView 實現，支援拖放功能
public struct OutlineGroupView<Item, RowContent>: NSViewRepresentable where Item: Identifiable, RowContent: View {
    // MARK: - 公開屬性

    /// 數據源
    private let data: [Item]

    /// 子項目的鍵路徑
    private let children: KeyPath<Item, [Item]?>

    /// 行內容構建器
    private let rowContent: (Item) -> RowContent

    /// 拖放配置
    private var dragDropConfig: DragDropConfiguration<Item>?

    /// 選擇模式
    private var selectionMode: SelectionMode = .none

    /// 已選中項目的 ID 集合
    private var selection: Binding<Set<Item.ID>>?

    /// 選擇變化的回調
    private var onSelectionChanged: (([Item]) -> Void)?

    // MARK: - 初始化方法

    /// 創建一個大綱視圖
    /// - Parameters:
    ///   - data: 數據源
    ///   - children: 子項目的鍵路徑
    ///   - rowContent: 行內容構建器
    public init(_ data: [Item], children: KeyPath<Item, [Item]?>, @ViewBuilder rowContent: @escaping (Item) -> RowContent) {
        self.data = data
        self.children = children
        self.rowContent = rowContent
    }

    // MARK: - NSViewRepresentable

    public func makeNSView(context: Context) -> NSScrollView {
        // 創建 NSOutlineView
        let outlineView = NSOutlineView()
        outlineView.style = .sourceList
        outlineView.selectionHighlightStyle = .sourceList
        outlineView.rowSizeStyle = .default
        outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        outlineView.usesAutomaticRowHeights = true
        outlineView.headerView = nil

        // 設置選擇模式
        switch selectionMode {
        case .none:
            outlineView.allowsEmptySelection = true
            outlineView.allowsMultipleSelection = false
        case .single:
            outlineView.allowsEmptySelection = false
            outlineView.allowsMultipleSelection = false
        case .multiple:
            outlineView.allowsEmptySelection = true
            outlineView.allowsMultipleSelection = true
        }

        // 設置代理和數據源
        outlineView.delegate = context.coordinator
        outlineView.dataSource = context.coordinator

        // 設置拖放相關屬性
        if dragDropConfig != nil {
            outlineView.setDraggingSourceOperationMask(.move, forLocal: true)
            outlineView.registerForDraggedTypes([.data])
        }

        // 創建列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Column"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)

        // 將 OutlineView 放入 ScrollView
        let scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let outlineView = nsView.documentView as? NSOutlineView else { return }

        // 更新協調器的數據
        context.coordinator.data = data
        context.coordinator.children = children
        context.coordinator.dragDropConfig = dragDropConfig
        context.coordinator.selectionBinding = selection
        context.coordinator.onSelectionChanged = onSelectionChanged

        // 設置選擇模式
        switch selectionMode {
        case .none:
            outlineView.allowsEmptySelection = true
            outlineView.allowsMultipleSelection = false
        case .single:
            outlineView.allowsEmptySelection = false
            outlineView.allowsMultipleSelection = false
        case .multiple:
            outlineView.allowsEmptySelection = true
            outlineView.allowsMultipleSelection = true
        }

        // 刷新數據
        outlineView.reloadData()

        // 同步選中狀態
        if let selection = selection {
            let selectedIds = selection.wrappedValue
            outlineView.deselectAll(nil)

            // 查找並選中 ID 相符的項目
            for rowIndex in 0 ..< outlineView.numberOfRows {
                if let item = outlineView.item(atRow: rowIndex) as? Item,
                   selectedIds.contains(item.id)
                {
                    // 使用非過時API
                    let rowIndexSet = IndexSet(integer: rowIndex)
                    outlineView.selectRowIndexes(rowIndexSet, byExtendingSelection: true)
                }
            }
        }

        // 展開所有項目
        expandItems(nil, outlineView: outlineView, coordinator: context.coordinator)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self, data: data, children: children, selectionBinding: selection, onSelectionChanged: onSelectionChanged)
    }

    // MARK: - 輔助方法

    private func expandItems(_ item: Any?, outlineView: NSOutlineView, coordinator: Coordinator) {
        let count = coordinator.outlineView(outlineView, numberOfChildrenOfItem: item)

        for index in 0 ..< count {
            let child = coordinator.outlineView(outlineView, child: index, ofItem: item)
            outlineView.expandItem(child)
            expandItems(child, outlineView: outlineView, coordinator: coordinator)
        }
    }

    // MARK: - 修飾符

    /// 設置拖放配置
    /// - Parameter config: 拖放配置
    /// - Returns: 更新後的視圖
    public func dragDropConfiguration(_ config: DragDropConfiguration<Item>) -> Self {
        var view = self
        view.dragDropConfig = config
        return view
    }

    /// 設置選擇模式
    /// - Parameter mode: 選擇模式 (無、單選、多選)
    /// - Returns: 更新後的視圖
    public func selectionMode(_ mode: SelectionMode) -> Self {
        var view = self
        view.selectionMode = mode
        return view
    }

    /// 綁定選中項目
    /// - Parameter selection: 選中項目 ID 的集合綁定
    /// - Returns: 更新後的視圖
    public func selection(_ selection: Binding<Set<Item.ID>>) -> Self {
        var view = self
        view.selection = selection
        view.selectionMode = view.selectionMode != .none ? view.selectionMode : .multiple
        return view
    }

    /// 設置選擇變化的回調
    /// - Parameter action: 選擇變化時調用的閉包，參數是選中的項目數組
    /// - Returns: 更新後的視圖
    public func onSelectionChanged(_ action: @escaping ([Item]) -> Void) -> Self {
        var view = self
        view.onSelectionChanged = action
        return view
    }

    // MARK: - 協調器

    public class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        private var parent: OutlineGroupView
        var data: [Item]
        var children: KeyPath<Item, [Item]?>
        var dragDropConfig: DragDropConfiguration<Item>?
        var selectionBinding: Binding<Set<Item.ID>>?
        var onSelectionChanged: (([Item]) -> Void)?

        init(
            _ parent: OutlineGroupView,
            data: [Item],
            children: KeyPath<Item, [Item]?>,
            selectionBinding: Binding<Set<Item.ID>>? = nil,
            onSelectionChanged: (([Item]) -> Void)? = nil
        ) {
            self.parent = parent
            self.data = data
            self.children = children
            self.selectionBinding = selectionBinding
            self.onSelectionChanged = onSelectionChanged
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

            // 觸發選擇變化回調
            onSelectionChanged?(selectedItems)
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

                if let children = item[keyPath: children],
                   let found = findItemByStringId(idString, in: children)
                {
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

                if let children = item[keyPath: children],
                   let found = findItem(with: id, in: children)
                {
                    return found
                }
            }
            return nil
        }
    }
}

// MARK: - 拖放配置

/// 拖放配置
public struct DragDropConfiguration<Item> {
    /// 驗證拖放操作
    let validateDrop: (Item?, Int) -> Bool

    /// 執行拖放操作
    let performDrop: (Item, Item?, Int) -> Bool

    /// 創建拖放配置
    /// - Parameters:
    ///   - validateDrop: 驗證函數，接收目標項目和索引，返回是否允許拖放
    ///   - performDrop: 執行函數，接收源項目、目標項目和索引，返回是否成功
    public init(
        validateDrop: @escaping (Item?, Int) -> Bool,
        performDrop: @escaping (Item, Item?, Int) -> Bool
    ) {
        self.validateDrop = validateDrop
        self.performDrop = performDrop
    }
}

// MARK: - 選擇模式

/// 選擇模式定義
public enum SelectionMode {
    /// 不允許選擇
    case none
    /// 單選模式
    case single
    /// 多選模式
    case multiple
}

// MARK: - 擴展

extension NSPasteboard.PasteboardType {
    static let data = NSPasteboard.PasteboardType("com.outlinegroupview.item")
}
