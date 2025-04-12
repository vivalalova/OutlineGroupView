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

    // 刷新數據
    outlineView.reloadData()

    // 展開所有項目
    expandItems(nil, outlineView: outlineView, coordinator: context.coordinator)
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(self, data: data, children: children)
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

  // MARK: - 協調器

  public class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private var parent: OutlineGroupView
    var data: [Item]
    var children: KeyPath<Item, [Item]?>
    var dragDropConfig: DragDropConfiguration<Item>?

    init(_ parent: OutlineGroupView, data: [Item], children: KeyPath<Item, [Item]?>) {
      self.parent = parent
      self.data = data
      self.children = children
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

// MARK: - 擴展

extension NSPasteboard.PasteboardType {
  static let data = NSPasteboard.PasteboardType("com.outlinegroupview.item")
}

// MARK: - 使用示例

#if DEBUG
  /// 使用 OutlineGroupView 的示例代碼
  /// 這個檔案展示了如何使用 OutlineGroupView 並實現拖放功能
  public enum OutlineGroupViewExample {
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
      @State private var items: [TreeItem]

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
              Spacer()
            }
            .padding(.vertical, 2)
          }
          .dragDropConfiguration(DragDropConfiguration(
            validateDrop: { _, _ in
              // 驗證拖放 - 這裡我們允許所有拖放操作
              true
            },
            performDrop: { source, destination, index in
              // 執行拖放 - 這裡展示了一個簡單的實現
              // 在實際應用中，你需要更新你的數據模型
              print("將 \(source.name) 移動到 \(destination?.name ?? "根層級") 的索引 \(index)")

              // 示例不實際執行移動，僅作演示
              return true
            }
          ))
          .frame(height: 300)
          .padding()

          Text("提示：在實際應用中，你需要實現 performDrop 來更新你的數據模型")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
        }
        .frame(width: 400)
      }
    }
  }
#endif

// MARK: - Preview

#if DEBUG
  /// 預覽用的測試項目
  fileprivate struct PreviewItem: Identifiable {
    let id = UUID()
    let name: String
    var children: [PreviewItem]?
  }

  struct OutlineGroupView_Previews: PreviewProvider {
    static var previews: some View {
      OutlineGroupView(previewData, children: \.children) { item in
        Text(item.name)
          .padding(.vertical, 4)
      }
      .frame(width: 300, height: 400)

      // 示例視圖預覽
      OutlineGroupViewExample.DemoView()
        .previewDisplayName("使用示例")
    }

    fileprivate static var previewData: [PreviewItem] = [
      PreviewItem(name: "群組 1", children: [
        PreviewItem(name: "項目 1-1", children: nil),
        PreviewItem(name: "項目 1-2", children: [
          PreviewItem(name: "子項目 1-2-1", children: nil),
          PreviewItem(name: "子項目 1-2-2", children: nil),
        ]),
      ]),
      PreviewItem(name: "群組 2", children: [
        PreviewItem(name: "項目 2-1", children: nil),
        PreviewItem(name: "項目 2-2", children: nil),
      ]),
      PreviewItem(name: "項目 3", children: nil),
    ]
  }
#endif
