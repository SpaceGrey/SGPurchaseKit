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
///     .purchaseStatus()               // Uses `SGPurchases.defaultGroup`
/// ```
///
/// In any descendant view you can read the status via:
/// ```swift
/// @Environment(\.purchaseStatus) private var purchaseStatus
/// ```
/// `purchaseStatus.defaultGroupStatus` represents the default group's status.
/// Other groups can be accessed with `purchaseStatus["groupName"]`.
public struct PurchaseViewModifier: ViewModifier {
    @State private var state = PurchaseStatus()

    public init() {}


    public func body(content: Content) -> some View {
        content
            .environment(\.purchaseStatus, state)
            // Observe purchase status update notifications
            .onReceive(NotificationCenter.default.publisher(for: .purchaseStatusUpdated)) { noti in
                guard let ps = noti.userInfo?["status"] as? PurchaseStatus else { return }
                state = ps
                Logger.log("update injected purchase status \(ps)")
            }
            // Preload the default group's status on first appearance
            .task {
                if let g = SGPurchases.defaultGroup {
                    let purchased = await SGPurchases.shared.checkGroupStatus(g)
                    state = PurchaseStatus(groupStatuses: [g: purchased])
                }
            }
    }
}

// MARK: - View Extension
public extension View {
    /// Injects `purchaseStatus` into the `Environment` so child views can access it.
    func injectPurchaseStatus() -> some View {
        modifier(PurchaseViewModifier())
    }
}
