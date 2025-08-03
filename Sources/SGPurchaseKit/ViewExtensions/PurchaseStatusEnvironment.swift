import SwiftUI

/// 在环境中传递的购买状态数据结构
public struct PurchaseStatus: Equatable {
    /// 所有分组的购买状态，键为分组名称，值表示是否已购买
    public var groupStatuses: [String: Bool]

    /// 当前 `SGPurchases.defaultGroup` 的购买状态。
    /// 若 `defaultGroup` 为 `nil`，此属性返回 `nil`。
    public var defaultGroupStatus: Bool? {
        guard let g = SGPurchases.defaultGroup else { return nil }
        return groupStatuses[g]
    }

    public init(groupStatuses: [String: Bool] = [:]) {
        self.groupStatuses = groupStatuses
    }

    /// 通过下标快速读取某个分组的购买状态
    public subscript(group: String) -> Bool {
        groupStatuses[group] ?? false
    }
}

// MARK: - EnvironmentKey & EnvironmentValues

private struct PurchaseStatusKey: EnvironmentKey {
    static let defaultValue: PurchaseStatus = PurchaseStatus()
}

public extension EnvironmentValues {
    /// 通过 `@Environment(\.purchaseStatus)` 读取或写入当前的购买状态集合
    var purchaseStatus: PurchaseStatus {
        get { self[PurchaseStatusKey.self] }
        set { self[PurchaseStatusKey.self] = newValue }
    }
}