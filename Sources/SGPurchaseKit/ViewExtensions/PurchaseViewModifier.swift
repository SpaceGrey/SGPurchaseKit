import Combine
import SwiftUI

/// Injects purchase status for all configured groups into the SwiftUI environment.
public struct PurchaseViewModifier: ViewModifier {
    @State private var state = PurchaseStatus()

    public init() {}

    public func body(content: Content) -> some View {
        content
            .environment(\.sgPurchaseStatus, state)
            .onReceive(NotificationCenter.default.publisher(for: .purchaseStatusUpdated)) { notification in
                guard let purchaseStatus = notification.userInfo?[PurchaseStatusNotificationUserInfoKey.status] as? PurchaseStatus else {
                    Logger.log("Received purchase status update notification without a valid PurchaseStatus payload")
                    return
                }
                apply(purchaseStatus, source: "notification")
            }
            .task {
                await loadInitialPurchaseStatus()
            }
    }

    private func loadInitialPurchaseStatus() async {
        Logger.log("Starting cached SwiftUI purchase status bootstrap")
        let cachedPurchaseStatus = await SGPurchases.shared.cachedPurchaseStatus()
        await MainActor.run {
            apply(cachedPurchaseStatus, source: "cache bootstrap")
        }

        Logger.log("Starting initial SwiftUI purchase status refresh")
        let purchaseStatus = await SGPurchases.shared.currentPurchaseStatus()
        await MainActor.run {
            apply(purchaseStatus, source: "initial refresh")
        }
    }

    @MainActor
    private func apply(_ purchaseStatus: PurchaseStatus, source: String) {
        guard purchaseStatus != state else {
            Logger.log("Skipping \(source) SwiftUI purchase status injection because state is unchanged: \(purchaseStatus.logDescription)")
            return
        }

        Logger.log("Applying \(source) SwiftUI purchase status injection: \(purchaseStatus.logDescription)")
        state = purchaseStatus
    }
}

public extension View {
    func injectPurchaseStatus() -> some View {
        modifier(PurchaseViewModifier())
    }
}
