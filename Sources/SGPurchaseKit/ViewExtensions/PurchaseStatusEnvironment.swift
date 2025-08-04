import SwiftUI

/// Purchase status data passed through SwiftUI Environment
public struct PurchaseStatus: Equatable {
    /// Purchase status for all groups; key is the group name, value indicates whether the user has purchased
    public var groupStatuses: [String: Bool]

    /// Purchase status of the current `SGPurchases.defaultGroup`.
    /// Returns `nil` when `defaultGroup` is `nil`. 
    public var defaultGroupStatus: Bool? {
        guard let g = SGPurchases.defaultGroup else { return nil }
        return groupStatuses[g]
    }

    public init(groupStatuses: [String: Bool] = [:]) {
        self.groupStatuses = groupStatuses
    }

    /// Subscript helper to retrieve a group's purchase status quickly
    public subscript(group: String) -> Bool {
        groupStatuses[group] ?? false
    }
}

// MARK: - EnvironmentKey & EnvironmentValues

private struct PurchaseStatusKey: EnvironmentKey {
    static let defaultValue: PurchaseStatus = PurchaseStatus()
}

public extension EnvironmentValues {
    /// Accessor for reading or writing the current `PurchaseStatus` via `@Environment(\.purchaseStatus)`
    var purchaseStatus: PurchaseStatus {
        get { self[PurchaseStatusKey.self] }
        set { self[PurchaseStatusKey.self] = newValue }
    }
}