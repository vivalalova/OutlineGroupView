//
//  OutlineGroupViewExample.swift
//  OutlineGroupView
//
//  Created by lova on 2025/4/12.
//

import Foundation
import SwiftUI

/// 展示使用方法的視圖
public struct DemoView: View {
    @State var items: [TreeItem]
    @State var selectedItemIds = Set<TreeItem.ID>()
    @State var selectionInfo = "尚未選擇項目"
    @State var lastDragOperation = "尚未進行拖放操作"

    public var body: some View {
        DraggableOutlineView(
            items: $items,
            children: \.children,
            childrenSetter: { item, newChildren in
                item.children = newChildren
            },
            selectedItemIds: $selectedItemIds,
            onDragCompleted: { operationDescription in
                lastDragOperation = operationDescription
            },
            onSelectionChanged: { selectedItems in
                if selectedItems.isEmpty {
                    selectionInfo = "尚未選擇項目"
                } else {
                    selectionInfo = "已選擇: " + selectedItems.map { $0.name }.joined(separator: ", ")
                }
            }
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
    }
}

// MARK: - Preview

public struct TreeItem: Identifiable, Hashable {
    public let id = UUID()
    public var name: String
    public var children: [TreeItem]?
}

#Preview {
    @Previewable var previewData: [TreeItem] = [
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

    // 示例視圖預覽
    VStack {
        Text("可拖放大綱視圖示例")
            .font(.headline)
            .padding()

        DemoView(items: previewData)

        Divider()

//        Text(lastDragOperation)
//            .font(.callout)
//            .lineLimit(2)
//            .padding(.horizontal)
//            .padding(.top, 4)
//
//        Text(selectionInfo)
//            .font(.callout)
//            .lineLimit(2)
//            .padding(.horizontal)
//            .padding(.bottom, 4)

        Text("提示：按住Command鍵可選擇多個項目並一起拖放")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom)
    }
    .frame(width: 400)
}
