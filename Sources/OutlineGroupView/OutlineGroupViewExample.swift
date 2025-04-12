//
//  OutlineGroupViewExample.swift
//  OutlineGroupView
//
//  Created by lova on 2025/4/12.
//

import Foundation
import SwiftUI

// MARK: - Preview

public struct TreeItem: OutlineItem {
  public let id = UUID()
  public var name: String
  public var children: [TreeItem]?

  public static func == (lhs: TreeItem, rhs: TreeItem) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

#Preview {
  @Previewable @State var items: [TreeItem] = [
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

  @Previewable @State var selectedItemIds = Set<TreeItem.ID>()
  @Previewable @State var selectionInfo = "尚未選擇項目"

  // 示例視圖預覽
  VStack {
    Text("可拖放大綱視圖示例")
      .font(.headline)
      .padding()

    DraggableOutlineView(
      items: $items,
      selectedItemIds: $selectedItemIds
    ) { item in
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
    .onSelectionChanged { selectedItems in
      if selectedItems.isEmpty {
        selectionInfo = "尚未選擇項目"
      } else {
        selectionInfo = "已選擇: " + selectedItems.map { $0.name }.joined(separator: ", ")
      }
    }

    Divider()

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
