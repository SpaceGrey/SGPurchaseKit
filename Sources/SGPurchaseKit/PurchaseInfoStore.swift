import Foundation
import KeychainSwift

protocol PurchaseInfoPersisting {
    func save(_ purchaseInfo: SGProduct.PurchaseInfo, for productId: String)
    func load(_ productId: String) -> SGProduct.PurchaseInfo?
    func remove(_ productId: String)
}

final class PurchaseInfoStore: PurchaseInfoPersisting {
    static let shared = PurchaseInfoStore()
    
    private struct StoredPurchaseInfo {
        let source: String
        let purchaseInfo: SGProduct.PurchaseInfo
        let priority: Int
    }
    
    private let prefix = "SGProduct.PurchaseInfo"
    private let keychain = KeychainSwift()
    private let userDefaults: UserDefaults
    
    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func save(_ purchaseInfo: SGProduct.PurchaseInfo, for productId: String) {
        let key = storageKey(for: productId)
        guard let data = try? JSONEncoder().encode(purchaseInfo) else {
            Logger.log("Failed to encode purchase cache for \(productId)")
            return
        }
        if !keychain.set(data, forKey: key) {
            Logger.log("Failed to write purchase cache to Keychain for \(productId)")
        }
        userDefaults.set(data, forKey: key)
    }
    
    func load(_ productId: String) -> SGProduct.PurchaseInfo? {
        let key = storageKey(for: productId)
        let keychainRecord = decode(
            data: keychain.getData(key),
            productId: productId,
            source: "Keychain",
            priority: 1
        )
        let userDefaultsRecord = decode(
            data: userDefaults.data(forKey: key),
            productId: productId,
            source: "UserDefaults",
            priority: 0
        )
        let records = [keychainRecord, userDefaultsRecord].compactMap { $0 }
        guard let newest = records.max(by: isOlder) else {
            return nil
        }
        logSelection(productId: productId, keychainRecord: keychainRecord, userDefaultsRecord: userDefaultsRecord, selected: newest)
        return newest.purchaseInfo
    }
    
    func remove(_ productId: String) {
        let key = storageKey(for: productId)
        keychain.delete(key)
        userDefaults.removeObject(forKey: key)
    }
    
    private func storageKey(for productId: String) -> String {
        "\(prefix).\(productId)"
    }
    
    private func decode(
        data: Data?,
        productId: String,
        source: String,
        priority: Int
    ) -> StoredPurchaseInfo? {
        guard let data else {
            return nil
        }
        do {
            let purchaseInfo = try JSONDecoder().decode(SGProduct.PurchaseInfo.self, from: data)
            return StoredPurchaseInfo(source: source, purchaseInfo: purchaseInfo, priority: priority)
        } catch {
            Logger.log("Failed to decode purchase cache from \(source) for \(productId): \(error.localizedDescription)")
            return nil
        }
    }
    
    private func isOlder(lhs: StoredPurchaseInfo, rhs: StoredPurchaseInfo) -> Bool {
        if lhs.purchaseInfo.fetchTime == rhs.purchaseInfo.fetchTime {
            return lhs.priority < rhs.priority
        }
        return lhs.purchaseInfo.fetchTime < rhs.purchaseInfo.fetchTime
    }
    
    private func logSelection(
        productId: String,
        keychainRecord: StoredPurchaseInfo?,
        userDefaultsRecord: StoredPurchaseInfo?,
        selected: StoredPurchaseInfo
    ) {
        switch (keychainRecord, userDefaultsRecord) {
        case (nil, nil):
            return
        case (.some, nil), (nil, .some):
            Logger.log("Loaded purchase cache for \(productId) from \(selected.source) only")
        case let (.some(keychainRecord), .some(userDefaultsRecord)):
            if keychainRecord.purchaseInfo.fetchTime != userDefaultsRecord.purchaseInfo.fetchTime {
                Logger.log(
                    "Loaded purchase cache for \(productId) from \(selected.source) as newest snapshot. " +
                    "keychainFetchTime=\(keychainRecord.purchaseInfo.fetchTime), " +
                    "userDefaultsFetchTime=\(userDefaultsRecord.purchaseInfo.fetchTime)"
                )
            }
        }
    }
}
