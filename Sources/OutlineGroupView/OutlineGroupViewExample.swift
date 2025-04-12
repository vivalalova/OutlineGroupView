//
//  OutlineGroupViewExample.swift
//  OutlineGroupView
//
//  Created by lova on 2025/4/12.
//

import Foundation
import SwiftUI

// MARK: - 使用示例

/// 使用 OutlineGroupView 的示例代碼
/// 這個檔案展示了如何使用 OutlineGroupView 並實現拖放功能
enum OutlineGroupViewExample {
  /// 樹狀結構的數據模型
  public struct TreeItem: Identifiable, Hashable {
    public let id = UUID()
    public var name: String
    public var children: [TreeItem]?

    public init(name: String, children: [TreeItem]? = nil) {
      self.name = name
      self.children = children
    }
  }

  /// 生成示例數據
  public static func createSampleData() -> [TreeItem] {
    return [
      TreeItem(name: "文件夾 1", children: [
        TreeItem(name: "項目 1-1"),
        TreeItem(name: "項目 1-2", children: [
          TreeItem(name: "子項目 1-2-1"),
          TreeItem(name: "子項目 1-2-2"),
        ]),
      ]),
      TreeItem(name: "文件夾 2", children: [
        TreeItem(name: "項目 2-1"),
        TreeItem(name: "項目 2-2"),
      ]),
      TreeItem(name: "項目 3"),
    ]
  }

  /// 展示使用方法的視圖
  public struct DemoView: View {
    @State var items: [TreeItem]
    @State var selectedItemIds = Set<TreeItem.ID>()
    @State var selectionInfo = "尚未選擇項目"
    @State var lastDragOperation = "尚未進行拖放操作"

    public init(items: [TreeItem]? = nil) {
      _items = State(initialValue: items ?? OutlineGroupViewExample.createSampleData())
    }

    public var body: some View {
      VStack {
        Text("可拖放大綱視圖示例")
          .font(.headline)
          .padding()

        OutlineGroupView(items, children: \.children) { item in
          HStack {
            Image(systemName: item.children == nil ? "doc" : "folder")
              .foregroundColor(item.children == nil ? .blue : .orange)
            Text(item.name)

            if selectedItemIds.contains(item.id) {
              Spacer()
              Image(systemName: "checkmark")
                .foregroundColor(.green)
            } else {
              Spacer()
            }
          }
          .padding(.vertical, 2)
        }
        .dragDropConfiguration(DragDropConfiguration(
          validateDrop: { _, _ in
            // 驗證拖放操作
            // 額外邏輯可以加在這裡，例如防止項目被拖放到自己的子項目中
            true
          },
          performDrop: { source, destination, index in
            // 執行拖放並更新數據模型

            // 檢查是否為多選拖放
            let isMultiSelect = selectedItemIds.contains(source.id) && selectedItemIds.count > 1
            if isMultiSelect {
              // 處理多選拖放
              if let updatedItems = performMultiDragDrop(items: items, sourceIds: selectedItemIds, draggedItem: source, destination: destination, index: index) {
                items = updatedItems
                let selectedItemsStr = findItemsByIds(selectedItemIds, in: items)
                  .map { $0.name }.joined(separator: "、")
                lastDragOperation = "將多個項目「\(selectedItemsStr)」移動到\(destination == nil ? "根層級" : "「\(destination!.name)」")的索引 \(index)"
                return true
              }
            }
            // 處理單選拖放
            else if let updatedItems = performDragDrop(items: items, source: source, destination: destination, index: index) {
              items = updatedItems
              lastDragOperation = "將「\(source.name)」移動到\(destination == nil ? "根層級" : "「\(destination!.name)」")的索引 \(index)"
              return true
            }

            return false
          }
        ))
        .selection($selectedItemIds) // 綁定選中項目
        .frame(height: 300)
        .padding()

        Divider()

        Text(lastDragOperation)
          .font(.callout)
          .lineLimit(2)
          .padding(.horizontal)
          .padding(.top, 4)

        Text(selectionInfo)
          .font(.callout)
          .lineLimit(2)
          .padding(.horizontal)
          .padding(.bottom, 4)

        Text("提示：按住Command鍵可選擇多個項目並一起拖放")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.bottom)
      }
      .frame(width: 400)
    }

    /// 根據ID查找多個項目
    /// - Parameters:
    ///   - ids: 要查找的項目ID集合
    ///   - items: 數據源
    /// - Returns: 找到的項目數組
    private func findItemsByIds(_ ids: Set<TreeItem.ID>, in items: [TreeItem]) -> [TreeItem] {
      var result: [TreeItem] = []

      // 遞歸函數
      func findItems(in items: [TreeItem]) {
        for item in items {
          if ids.contains(item.id) {
            result.append(item)
          }

          if let children = item.children {
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
    private func performMultiDragDrop(
      items: [TreeItem],
      sourceIds: Set<TreeItem.ID>,
      draggedItem _: TreeItem,
      destination: TreeItem?,
      index: Int
    ) -> [TreeItem]? {
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
    private func sortItemsByTreeOrder(_ items: [TreeItem], in sourceItems: [TreeItem]) -> [TreeItem] {
      var result: [TreeItem] = []
      var foundIds = Set<TreeItem.ID>()
      let itemIds = Set(items.map { $0.id })

      // 遞歸查找函數
      func findInOrder(in currentItems: [TreeItem]) {
        for item in currentItems {
          if itemIds.contains(item.id) && !foundIds.contains(item.id) {
            result.append(item)
            foundIds.insert(item.id)
          }

          if let children = item.children {
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
    private func performDragDrop(
      items: [TreeItem],
      source: TreeItem,
      destination: TreeItem?,
      index: Int
    ) -> [TreeItem]? {
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
    private func removeItemFromTree(source: TreeItem, items: inout [TreeItem]) -> Bool {
      // 檢查當前層級
      if let index = items.firstIndex(where: { $0.id == source.id }) {
        items.remove(at: index)
        return true
      }

      // 遞歸檢查子層級
      for i in 0 ..< items.count {
        if var children = items[i].children {
          if removeItemFromTree(source: source, items: &children) {
            items[i].children = children
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
    private func addItemToNode(source: TreeItem, destinationNode: TreeItem, atIndex index: Int, items: inout [TreeItem]) -> Bool {
      // 檢查當前層級
      for i in 0 ..< items.count {
        if items[i].id == destinationNode.id {
          // 初始化子項目數組（如果為nil）
          if items[i].children == nil {
            items[i].children = []
          }

          // 添加項目到指定位置
          var children = items[i].children!
          if index >= 0 && index <= children.count {
            children.insert(source, at: index)
          } else {
            children.append(source) // 如果索引超出範圍，則添加到末尾
          }

          items[i].children = children
          return true
        }

        // 遞歸檢查子層級
        if var children = items[i].children {
          if addItemToNode(source: source, destinationNode: destinationNode, atIndex: index, items: &children) {
            items[i].children = children
            return true
          }
        }
      }

      return false
    }
  }
}
