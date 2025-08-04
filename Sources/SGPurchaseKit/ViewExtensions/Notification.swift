//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 3/8/25.
//

import Foundation
// MARK: - Notification Name

extension Notification.Name {
    /// Posted whenever any group's purchase status changes (local or remote transactions).
    static let purchaseStatusUpdated = Notification.Name("SGPurchaseKit.purchaseStatusUpdated")
}
