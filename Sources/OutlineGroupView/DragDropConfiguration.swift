//
//  DragDropConfiguration.swift
//  OutlineGroupView
//
//  Created by lova on 2025/4/13.
//

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
