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
                .selectionMode(.multiple) // 設定為多選模式
                .selection($selectedItemIds) // 綁定選中項目
                .onSelectionChanged { selectedItems in
                    if selectedItems.isEmpty {
                        selectionInfo = "尚未選擇項目"
                    } else {
                        selectionInfo = "已選擇: " + selectedItems.map { $0.name }.joined(separator: ", ")
                    }
                }
                .frame(height: 300)
                .padding()

                Divider()

                Text(selectionInfo)
                    .font(.callout)
                    .padding()

                Text("提示：按住Command鍵可選擇多個項目")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            .frame(width: 400)
        }
    }
}
