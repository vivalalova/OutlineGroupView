//
//  DraggableOutlineView.swift
//  OutlineGroupView
//
//  Created by lova on 2025/4/12.
//

import SwiftUI

/// 可拖放且支援多選的大綱視圖
/// 封裝了 OutlineGroupView 的常用配置
public struct DraggableOutlineView<Item: Identifiable & Hashable>: View {
    // 數據
    @Binding private var items: [Item]
    @Binding private var selectedItemIds: Set<Item.ID>

    // 配置
    private let children: KeyPath<Item, [Item]?>
    private let childrenSetter: ((inout Item, [Item]?) -> Void)?
    private let onDragCompleted: ((String) -> Void)?
    private var onSelectionChanged: (([Item]) -> Void)?

    // 自定義內容
    private let rowContent: (Item) -> any View

    /// 初始化可拖放大綱視圖
    /// - Parameters:
    ///   - items: 資料項目陣列綁定
    ///   - children: 子項目的鍵路徑
    ///   - childrenSetter: 設置子項目的閉包
    ///   - selectedItemIds: 已選擇項目ID的集合綁定
    ///   - onDragCompleted: 拖放完成後的回調
    ///   - onSelectionChanged: 選擇變化的回調
    ///   - rowContent: 行內容構建器
    public init(
        items: Binding<[Item]>,
        children: KeyPath<Item, [Item]?>,
        childrenSetter: ((inout Item, [Item]?) -> Void)?,
        selectedItemIds: Binding<Set<Item.ID>>,
        onDragCompleted: ((String) -> Void)? = nil,
        onSelectionChanged: (([Item]) -> Void)? = nil,
        @ViewBuilder rowContent: @escaping (Item) -> any View
    ) {
        _items = items
        self.children = children
        self.childrenSetter = childrenSetter
        _selectedItemIds = selectedItemIds
        self.onDragCompleted = onDragCompleted
        self.onSelectionChanged = onSelectionChanged
        self.rowContent = rowContent
    }

    public var body: some View {
        OutlineGroupView(items, children: children) { item in
            AnyView(rowContent(item))
        }
        .dragDropConfiguration(DragDropConfiguration(
            validateDrop: { _, _ in
                // 驗證拖放操作
                // 可以在這裡添加額外邏輯，例如防止項目被拖放到自己的子項目中
                true
            },
            performDrop: { source, destination, index in
                // 執行拖放並更新數據模型

                // 檢查是否為多選拖放
                let isMultiSelect = selectedItemIds.contains(source.id) && selectedItemIds.count > 1

                if isMultiSelect {
                    // 處理多選拖放
                    if let updatedItems = performMultiDragDrop(
                        items: items,
                        sourceIds: selectedItemIds,
                        draggedItem: source,
                        destination: destination,
                        index: index
                    ) {
                        items = updatedItems
                        let selectedItemsStr = findItemsByIds(selectedItemIds, in: items)
                            .map { String(describing: $0) }.joined(separator: "、")
                        let operationDescription = "將多個項目「\(selectedItemsStr)」移動到\(destination == nil ? "根層級" : "「\(String(describing: destination!))」")的索引 \(index)"
                        onDragCompleted?(operationDescription)
                        return true
                    }
                } else {
                    // 處理單選拖放
                    if let updatedItems = performDragDrop(
                        items: items,
                        source: source,
                        destination: destination,
                        index: index
                    ) {
                        items = updatedItems
                        let operationDescription = "將「\(String(describing: source))」移動到\(destination == nil ? "根層級" : "「\(String(describing: destination!))」")的索引 \(index)"
                        onDragCompleted?(operationDescription)
                        return true
                    }
                }

                return false
            }
        ))
        .selectionMode(.multiple) // 設定為多選模式
        .selection($selectedItemIds) // 綁定選中項目
        .if(onSelectionChanged != nil) { view in
            view.onSelectionChanged { items in
                self.onSelectionChanged?(items)
            }
        }
    }

    /// 設置選擇變化的回調
    /// - Parameter action: 選擇變化時調用的閉包，參數是選中的項目數組
    /// - Returns: 更新後的視圖
    public func onSelectionChanged(_ action: @escaping ([Item]) -> Void) -> Self {
        var view = self
        view.onSelectionChanged = action
        return view
    }

    /// 根據ID查找多個項目
    /// - Parameters:
    ///   - ids: 要查找的項目ID集合
    ///   - items: 數據源
    /// - Returns: 找到的項目數組
    private func findItemsByIds(_ ids: Set<Item.ID>, in items: [Item]) -> [Item] {
        var result: [Item] = []

        // 遞歸函數
        func findItems(in items: [Item]) {
            for item in items {
                if ids.contains(item.id) {
                    result.append(item)
                }

                if let children = item[keyPath: children] {
                    findItems(in: children)
                }
            }
        }

        findItems(in: items)
        return result
    }

    /// 執行多選拖放操作
    /// - Parameters:
    ///   - items: 當前數據
    ///   - sourceIds: 所有選中項目的ID集合
    ///   - draggedItem: 實際被拖動的項目
    ///   - destination: 目標項目
    ///   - index: 目標索引
    /// - Returns: 更新後的數據
    private func performMultiDragDrop(items: [Item], sourceIds: Set<Item.ID>, draggedItem _: Item, destination: Item?, index: Int) -> [Item]? {
        // 創建數據副本
        var newItems = items

        // 找出所有需要移動的項目
        let itemsToMove = findItemsByIds(sourceIds, in: items)

        // 排序項目：確保保持樹中的相對順序
        let sortedItemsToMove = sortItemsByTreeOrder(itemsToMove, in: items)

        // 步驟1: 從樹中刪除所有項目
        for item in sortedItemsToMove {
            if !removeItemFromTree(source: item, items: &newItems) {
                return nil
            }
        }

        // 步驟2: 添加項目到目標位置
        if let destination = destination {
            // 添加到目標項目的子項目中
            var currentIndex = index
            for item in sortedItemsToMove {
                if !addItemToNode(source: item, destinationNode: destination, atIndex: currentIndex, items: &newItems) {
                    return nil
                }
                // 更新索引，確保項目按原有順序放置
                currentIndex += 1
            }
        } else {
            // 添加到根層級
            var currentIndex = index
            for item in sortedItemsToMove {
                if currentIndex >= 0 && currentIndex <= newItems.count {
                    newItems.insert(item, at: currentIndex)
                } else {
                    newItems.append(item)
                }
                // 更新索引，確保項目按原有順序放置
                currentIndex += 1
            }
        }

        return newItems
    }

    /// 根據樹中的順序排序項目
    /// - Parameters:
    ///   - items: 要排序的項目
    ///   - sourceItems: 原始數據源
    /// - Returns: 排序後的項目
    private func sortItemsByTreeOrder(_ items: [Item], in sourceItems: [Item]) -> [Item] {
        var result: [Item] = []
        var foundIds = Set<Item.ID>()
        let itemIds = Set(items.map { $0.id })

        // 遞歸查找函數
        func findInOrder(in currentItems: [Item]) {
            for item in currentItems {
                if itemIds.contains(item.id) && !foundIds.contains(item.id) {
                    result.append(item)
                    foundIds.insert(item.id)
                }

                if let children = item[keyPath: children] {
                    findInOrder(in: children)
                }
            }
        }

        findInOrder(in: sourceItems)
        return result
    }

    /// 執行拖放操作並更新數據模型
    /// - Parameters:
    ///   - items: 當前數據
    ///   - source: 拖動的源項目
    ///   - destination: 目標項目（如果是根層級，則為nil）
    ///   - index: 目標索引
    /// - Returns: 更新後的數據，如果操作失敗則返回nil
    private func performDragDrop(items: [Item], source: Item, destination: Item?, index: Int) -> [Item]? {
        // 創建一個可變的數據副本
        var newItems = items

        // 步驟1: 刪除源項目
        if !removeItemFromTree(source: source, items: &newItems) {
            return nil // 如果源項目不存在，則返回nil
        }

        // 步驟2: 添加項目到目標位置
        if let destination = destination {
            // 添加到目標項目的子項目中
            if !addItemToNode(source: source, destinationNode: destination, atIndex: index, items: &newItems) {
                return nil // 如果目標項目不存在，則返回nil
            }
        } else {
            // 添加到根層級
            if index >= 0 && index <= newItems.count {
                newItems.insert(source, at: index)
            } else {
                newItems.append(source) // 如果索引超出範圍，則添加到末尾
            }
        }

        return newItems
    }

    /// 從樹中刪除項目
    /// - Parameters:
    ///   - source: 要刪除的項目
    ///   - items: 數據樹
    /// - Returns: 是否成功刪除
    private func removeItemFromTree(source: Item, items: inout [Item]) -> Bool {
        // 檢查當前層級
        if let index = items.firstIndex(where: { $0.id == source.id }) {
            items.remove(at: index)
            return true
        }

        // 遞歸檢查子層級
        for i in 0 ..< items.count {
            if var children = items[i][keyPath: children] {
                if removeItemFromTree(source: source, items: &children) {
                    if let setter = childrenSetter {
                        var item = items[i]
                        setter(&item, children)
                        items[i] = item
                    } else {
                        // 如果沒有提供setter，則無法修改
                        return false
                    }
                    return true
                }
            }
        }

        return false
    }

    /// 將項目添加到指定節點的子項目中
    /// - Parameters:
    ///   - source: 要添加的項目
    ///   - destinationNode: 目標節點
    ///   - index: 添加位置的索引
    ///   - items: 數據樹
    /// - Returns: 是否成功添加
    private func addItemToNode(source: Item, destinationNode: Item, atIndex index: Int, items: inout [Item]) -> Bool {
        // 檢查當前層級
        for i in 0 ..< items.count {
            if items[i].id == destinationNode.id {
                // 初始化子項目數組（如果為nil）
                var children = items[i][keyPath: self.children] ?? []

                // 添加項目到指定位置
                if index >= 0 && index <= children.count {
                    children.insert(source, at: index)
                } else {
                    children.append(source) // 如果索引超出範圍，則添加到末尾
                }

                if let setter = childrenSetter {
                    var item = items[i]
                    setter(&item, children)
                    items[i] = item
                } else {
                    // 如果沒有提供setter，則無法修改
                    return false
                }
                return true
            }

            // 遞歸檢查子層級
            if var children = items[i][keyPath: children] {
                if addItemToNode(source: source, destinationNode: destinationNode, atIndex: index, items: &children) {
                    if let setter = childrenSetter {
                        var item = items[i]
                        setter(&item, children)
                        items[i] = item
                    } else {
                        // 如果沒有提供setter，則無法修改
                        return false
                    }
                    return true
                }
            }
        }

        return false
    }
}

// 條件修飾器
private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
