import Foundation

extension Notification.Name {
    /// Posted whenever purchase status changes after a refresh or remote transaction update.
    static let purchaseStatusUpdated = Notification.Name("SGPurchaseKit.purchaseStatusUpdated")
}

enum PurchaseStatusNotificationUserInfoKey {
    static let status = "status"
}
