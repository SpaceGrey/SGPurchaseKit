//
//  PurchaseViewModifier.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 3/8/25.
//

import SwiftUI
import Combine

// MARK: - EnvironmentKey & EnvironmentValues

private struct PurchaseStatusKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    /// Indicates whether the user has already purchased the content.
    var purchaseStatus: Bool {
        get { self[PurchaseStatusKey.self] }
        set { self[PurchaseStatusKey.self] = newValue }
    }
}

// MARK: - ViewModifier

/// A `ViewModifier` that injects the user's purchase status into the view hierarchy.
///
/// Usage:
/// ```swift
/// ContentView()
///     .purchaseStatus(group: "live photo")
/// ```
/// Inside any descendant view, you can access the status via:
/// ```swift
/// @Environment(\.purchaseStatus) private var purchased
/// ```
public struct PurchaseViewModifier: ViewModifier {
    /// The purchase group to check. If `nil`, `SGPurchases.defaultGroup` is used.
    private let group: String?
    @State private var purchased: Bool = false

    public init(group: String? = nil) {
        self.group = group
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.purchaseStatus, purchased)
            .onReceive(NotificationCenter.default.publisher(for: .purchaseStatusUpdated)) { noti in
                if let p = noti.userInfo?["purchased"] as? Bool {
                    purchased = p
                }
            }
            .task {
                // Initial query of purchase status
                let status = await SGPurchases.shared.checkGroupStatus(group)
                purchased = status
            }
    }
}

// MARK: - View Extension

public extension View {
    /// Injects `purchaseStatus` into `EnvironmentValues` so descendant views can access it.
    /// - Parameter group: The purchase group to check. Defaults to `SGPurchases.defaultGroup`.
    /// - Returns: A view with purchase status injected.
    func purchaseStatus(group: String? = nil) -> some View {
        modifier(PurchaseViewModifier(group: group))
    }
}
