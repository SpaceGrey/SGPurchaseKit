import Foundation
import SwiftUI

/// Purchase status injected into the SwiftUI environment.
public struct PurchaseStatus: Equatable, Codable, Sendable {
    public var groupStatuses: [String: Bool]

    /// Purchase status of the current `SGPurchases.defaultGroup`.
    /// Returns `nil` when no default group is configured.
    public var defaultGroupStatus: Bool? {
        guard let group = SGPurchases.defaultGroup else {
            return nil
        }
        return groupStatuses[group]
    }

    public init(groupStatuses: [String: Bool] = [:]) {
        self.groupStatuses = groupStatuses
    }

    public subscript(group: String) -> Bool {
        groupStatuses[group] ?? false
    }
}

extension PurchaseStatus {
    var logDescription: String {
        guard !groupStatuses.isEmpty else {
            return "empty"
        }

        return groupStatuses.keys.sorted().map { group in
            let status = groupStatuses[group] == true ? "purchased" : "notPurchased"
            return "\(group)=\(status)"
        }.joined(separator: ", ")
    }
}

private struct PurchaseStatusKey: EnvironmentKey {
    static let defaultValue = PurchaseStatus()
}

public extension EnvironmentValues {
    var sgPurchaseStatus: PurchaseStatus {
        get { self[PurchaseStatusKey.self] }
        set { self[PurchaseStatusKey.self] = newValue }
    }
}
