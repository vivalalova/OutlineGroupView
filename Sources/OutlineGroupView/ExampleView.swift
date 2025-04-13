//
//  File.swift
//  OutlineGroupView
//
//  Created by lova on 2025/4/13.
//

import SwiftUI

// MARK: - Preview2

/// 資料夾項目
struct FolderItem: SidebarItem {
    let id = UUID()
    var name: String
    var children: [FolderItem]?
}

/// 檔案項目
struct FileItem: SidebarItem {
    let id = UUID()
    var name: String
    var children: [FileItem]? = nil // 檔案通常沒有子項
}

// 顯示不同項目類型的預覽
#Preview(traits: .fixedLayout(width: 300, height: 500)) {
    @Previewable @State var folders: [FolderItem] = [
        FolderItem(name: "專案資料夾", children: [
            FolderItem(name: "源碼", children: [
                FolderItem(name: "模型", children: [
                    FolderItem(name: "用戶模型"),
                    FolderItem(name: "產品模型"),
                    FolderItem(name: "訂單模型"),
                ]),
                FolderItem(name: "視圖", children: [
                    FolderItem(name: "主視圖"),
                    FolderItem(name: "設置視圖"),
                    FolderItem(name: "用戶視圖"),
                ]),
                FolderItem(name: "控制器"),
            ]),
            FolderItem(name: "資源", children: [
                FolderItem(name: "圖片"),
                FolderItem(name: "字體"),
                FolderItem(name: "本地化"),
            ]),
            FolderItem(name: "測試", children: [
                FolderItem(name: "單元測試"),
                FolderItem(name: "UI測試"),
            ]),
        ]),
        FolderItem(name: "文檔", children: [
            FolderItem(name: "API文檔"),
            FolderItem(name: "用戶手冊"),
            FolderItem(name: "開發文檔"),
        ]),
        FolderItem(name: "工具", children: [
            FolderItem(name: "腳本"),
            FolderItem(name: "配置"),
        ]),
    ]

    @Previewable @State var selectedFolders: [FolderItem] = []

    // 示例視圖預覽
    VStack {
        SideBarContentView(items: $folders, selectedItems: $selectedFolders)
    }
}
