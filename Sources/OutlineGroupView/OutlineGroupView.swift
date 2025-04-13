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
  let data: [Item]
  /// 子項目的鍵路徑
  let children: KeyPath<Item, [Item]?>
  /// 行內容構建器
  let rowContent: (Item) -> RowContent

  /// 拖放配置
  private var dragDropConfig: DragDropConfiguration<Item>?

  /// 已選中項目的 ID 集合
  private var selectedItemIds: Binding<Set<Item.ID>>?

  // MARK: - 初始化方法

  /// 創建一個大綱視圖
  /// - Parameters:
  ///   - data: 數據源
  ///   - children: 子項目的鍵路徑
  ///   - rowContent: 行內容構建器
  public init(_ data: [Item], children: KeyPath<Item, [Item]?>, selectedItemIds: Binding<Set<Item.ID>>? = nil, @ViewBuilder rowContent: @escaping (Item) -> RowContent) {
    self.data = data
    self.children = children
    self.selectedItemIds = selectedItemIds
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

    // 設定可多選
    outlineView.allowsEmptySelection = true
    outlineView.allowsMultipleSelection = true

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
    context.coordinator.selectionBinding = selectedItemIds

    // 設置選擇模式
    outlineView.allowsEmptySelection = true
    outlineView.allowsMultipleSelection = true

    // 刷新數據
    outlineView.reloadData()

    // 同步選中狀態
    if let selection = selectedItemIds {
      let selectedIds = selection.wrappedValue
      outlineView.deselectAll(nil)

      // 查找並選中 ID 相符的項目
      for rowIndex in 0 ..< outlineView.numberOfRows {
        if let item = outlineView.item(atRow: rowIndex) as? Item, selectedIds.contains(item.id) {
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
    Coordinator(self, data: data, children: children, selectionBinding: selectedItemIds)
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
}

// MARK: - 修飾符

public extension OutlineGroupView {
  /// 設置拖放配置
  /// - Parameter config: 拖放配置
  /// - Returns: 更新後的視圖
  func dragDropConfiguration(_ config: DragDropConfiguration<Item>) -> Self {
    var view = self
    view.dragDropConfig = config
    return view
  }
}
