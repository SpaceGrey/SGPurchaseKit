import SwiftUI
import Foundation

/// Purchase status data passed through SwiftUI Environment
public struct PurchaseStatus: Equatable, Codable {
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

// MARK: - Persistence (UserDefaults)

extension PurchaseStatus {
    private static let storageKey = "SGPurchaseKit.PurchaseStatus"

    /// Load cached status from UserDefaults
    static func loadFromDefaults() -> PurchaseStatus? {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: storageKey) {
            if let decoded = try? JSONDecoder().decode(PurchaseStatus.self, from: data) {
                return decoded
            }
        }
        // Backward compatibility: plain dictionary
        if let dict = defaults.dictionary(forKey: storageKey) as? [String: Bool] {
            return PurchaseStatus(groupStatuses: dict)
        }
        return nil
    }

    /// Persist current status to UserDefaults
    func saveToDefaults() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        } else {
            // Fallback to plain dictionary if encoding fails
            defaults.set(groupStatuses, forKey: Self.storageKey)
        }
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