//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 3/8/25.
//

import Foundation
// MARK: - Notification Name

public extension Notification.Name {
    /// Posted whenever a purchase status update occurs (local or remote transactions).
    public static let purchaseStatusUpdated = Notification.Name("SGPurchaseKit.purchaseStatusUpdated")
}
