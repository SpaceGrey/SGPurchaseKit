//
//  PurchaseViewModifier.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 3/8/25.
//

import SwiftUI
import Combine

/// 一个 `ViewModifier`，将所有分组的购买状态注入到视图层级中。
///
/// 用法：
/// ```swift
/// ContentView()
///     .purchaseStatus()                     // 使用默认分组
///     .purchaseStatus(group: "video")    // 指定默认分组
/// ```
///
/// 在任意子视图中可通过以下方式获取：
/// ```swift
/// @Environment(\.purchaseStatus) private var purchaseStatus
/// ```
/// `purchaseStatus.defaultGroupStatus` 表示默认分组的购买状态，
/// 其他分组的状态可通过 `purchaseStatus["groupName"]` 查询。
public struct PurchaseViewModifier: ViewModifier {
    /// 指定哪个分组作为 *默认* 分组；若为 `nil` 则使用 `SGPurchases.defaultGroup`。
    private let group: String?

    @State private var state = PurchaseStatus()

    public init(group: String? = nil) {
        self.group = group
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.purchaseStatus, state)
            // 监听购买状态更新通知
            .onReceive(NotificationCenter.default.publisher(for: .purchaseStatusUpdated)) { noti in
                guard let ps = noti.userInfo?["status"] as? PurchaseStatus else { return }
                state = ps
            }
            // 首次进入视图时预加载默认分组的状态
            .task {
                let targetGroup = group ?? SGPurchases.defaultGroup
                if let g = targetGroup {
                    let purchased = await SGPurchases.shared.checkGroupStatus(g)
                    state = PurchaseStatus(groupStatuses: [g: purchased])
                }
            }
    }
}

// MARK: - View 扩展
public extension View {
    /// 向 `Environment` 注入 `purchaseStatus`，供子视图读取。
    /// - Parameter group: 指定哪个分组作为 `defaultGroupStatus`，若为空则使用 `SGPurchases.defaultGroup`。
    func purchaseStatus(group: String? = nil) -> some View {
        modifier(PurchaseViewModifier(group: group))
    }
}