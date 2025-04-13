//
//  SidebarItem.swift
//  OutlineGroupView
//
//  Created by lova on 2025/4/13.
//

import SwiftUI

public protocol SidebarItem: Hashable, Identifiable {
  /// 實作用let
  var id: UUID { get }
  var name: String { get }
  var children: [Self]? { get set }
}
