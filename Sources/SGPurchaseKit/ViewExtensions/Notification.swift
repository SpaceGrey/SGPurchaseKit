//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 3/8/25.
//

import Foundation
// MARK: - Notification Name

public extension Notification.Name {
    /// 当任意分组的购买状态发生变化（本地或远程交易）时发送。
    public static let purchaseStatusUpdated = Notification.Name("SGPurchaseKit.purchaseStatusUpdated")
}
