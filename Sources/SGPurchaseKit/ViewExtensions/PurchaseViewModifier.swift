//
//  PurchaseViewModifier.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 3/8/25.
//

import SwiftUI
import Combine

/// A `ViewModifier` that injects purchase statuses for **all** groups into the view hierarchy.
///
/// Usage:
/// ```swift
/// ContentView()
///     .purchaseStatus()               // Use the library's `defaultGroup`
///     .purchaseStatus(group: "video") // Specify an explicit default group
/// ```
///
/// In any descendant view you can read the status via:
/// ```swift
/// @Environment(\.purchaseStatus) private var purchaseStatus
/// ```
/// `purchaseStatus.defaultGroupStatus` represents the default group's status.
/// Other groups can be accessed with `purchaseStatus["groupName"]`. 
public struct PurchaseViewModifier: ViewModifier {
    /// The group treated as the *default* one; if `nil`, `SGPurchases.defaultGroup` is used.
    private let group: String?

    @State private var state = PurchaseStatus()

    public init(group: String? = nil) {
        self.group = group
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.purchaseStatus, state)
            // Observe purchase status update notifications
            .onReceive(NotificationCenter.default.publisher(for: .purchaseStatusUpdated)) { noti in
                guard let ps = noti.userInfo?["status"] as? PurchaseStatus else { return }
                state = ps
            }
            // Preload the default group's status on first appearance
            .task {
                let targetGroup = group ?? SGPurchases.defaultGroup
                if let g = targetGroup {
                    let purchased = await SGPurchases.shared.checkGroupStatus(g)
                    state = PurchaseStatus(groupStatuses: [g: purchased])
                }
            }
    }
}

// MARK: - View Extension
public extension View {
    /// Injects `purchaseStatus` into the `Environment` so child views can access it.
    /// - Parameter group: Specifies which group should act as `defaultGroupStatus`. If `nil`, `SGPurchases.defaultGroup` is used.
    func purchaseStatus(group: String? = nil) -> some View {
        modifier(PurchaseViewModifier(group: group))
    }
}