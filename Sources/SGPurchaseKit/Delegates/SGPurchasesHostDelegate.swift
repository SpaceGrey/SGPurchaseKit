import Foundation

/// Host integration callback for verified remote StoreKit transaction updates.
public protocol SGPurchasesHostDelegate: AnyObject {
    /// Called only when `SGPurchases` receives a verified remote transaction update from `Transaction.updates`.
    @MainActor
    func purchases(
        _ purchases: SGPurchases,
        didReceiveRemoteTransactionFor productID: String,
        purchaseStatus: PurchaseStatus
    )
}
