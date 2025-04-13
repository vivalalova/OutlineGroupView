//
//  File.swift
//  OutlineGroupView
//
//  Created by lova on 2025/4/13.
//

import SwiftUI

// MARK: - Preview1

/// 資料夾項目
struct FolderItem: SidebarItem {
    let id = UUID()
    var name: String
    var children: [FolderItem]?
}

#Preview(traits: .fixedLayout(width: 300, height: 500)) {
    @Previewable @State var previewData: [TreeItem] = [
        TreeItem(name: "群組 1", children: [
            TreeItem(name: "項目 1-1", children: nil),
            TreeItem(name: "項目 1-2", children: [
                TreeItem(name: "子項目 1-2-1", children: nil),
                TreeItem(name: "子項目 1-2-2", children: nil),
            ]),
        ]),
        TreeItem(name: "群組 2", children: [
            TreeItem(name: "項目 2-1", children: nil),
            TreeItem(name: "項目 2-2", children: nil),
        ]),
        TreeItem(name: "項目 3", children: nil),
        TreeItem(name: "群組 1", children: [
            TreeItem(name: "項目 1-1", children: nil),
            TreeItem(name: "項目 1-2", children: [
                TreeItem(name: "子項目 1-2-1", children: nil),
                TreeItem(name: "子項目 1-2-2", children: nil),
            ]),
        ]),
        TreeItem(name: "群組 2", children: [
            TreeItem(name: "項目 2-1", children: nil),
            TreeItem(name: "項目 2-2", children: nil),
        ]),
        TreeItem(name: "項目 3", children: nil),
        TreeItem(name: "項目 4", children: nil),
    ]

    @Previewable @State var selectedItems: [TreeItem] = []

    // 示例視圖預覽
    VStack {
        SideBarContentView(items: $previewData, selectedItems: $selectedItems)
    }
}

// MARK: - Preview2

/// 檔案項目
struct FileItem: SidebarItem {
    let id = UUID()
    var name: String
    var children: [FileItem]? = nil // 檔案通常沒有子項
}

/// 樹狀結構的數據模型 (保留以相容現有代碼)
struct TreeItem: SidebarItem {
    let id = UUID()
    var name: String
    var children: [TreeItem]?
}

// 顯示不同項目類型的預覽
#Preview(traits: .fixedLayout(width: 300, height: 500)) {
    @Previewable @State var folders: [FolderItem] = [
        FolderItem(name: "專案資料夾", children: [
            FolderItem(name: "源碼", children: [
                FolderItem(name: "模型"),
                FolderItem(name: "視圖"),
            ]),
            FolderItem(name: "資源"),
        ]),
        FolderItem(name: "文檔"),
    ]

    @Previewable @State var selectedFolders: [FolderItem] = []

    // 示例視圖預覽
    VStack {
        SideBarContentView(items: $folders, selectedItems: $selectedFolders)
    }
}
