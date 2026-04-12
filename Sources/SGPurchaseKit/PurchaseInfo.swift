//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 1/1/25.
//

import Foundation
import StoreKit
extension SGProduct{
    
    public enum PurchaseStatus{
        case trail, subscription, lifetime
    }
    
    public struct PurchaseInfo: Codable,Equatable {
        enum OwnershipType: String, Codable {
            case purchased
            case familyShared
            
            init(_ ownershipType: Transaction.OwnershipType) {
                if ownershipType == .familyShared {
                    self = .familyShared
                } else {
                    self = .purchased
                }
            }
        }
        
        private static let store: PurchaseInfoPersisting = PurchaseInfoStore.shared
        var fetchTime:Double
        var offerType:Transaction.OfferType?
        var ownershipType: OwnershipType?
        var active:Bool = true
        var expireTime:Double?
        var isCache:Bool = true
        var hasPurchased:Bool{
            guard active else {
                return false
            }
            guard isCache else {
                return true
            }
            switch SGPurchases.fallbackPolicy {
            case .alwaysKeepPurchase:
                let now = Date.now.timeIntervalSince1970
                if now > expireTime ?? .infinity {
                    return false
                } else {
                    return true
                }
            case .days(let days):
                let now = Date.now.timeIntervalSince1970
                let cacheExpiredDate = fetchTime + Double(days * 24 * 3600)
                if now > cacheExpiredDate || now > expireTime ?? .infinity{
                    return false
                } else {
                    return true
                }
            case .off:
                return false
            }
        }
        
        var purchaseStatus:PurchaseStatus?{
            guard hasPurchased else {
                return nil
            }
            if offerType == .introductory {
                return .trail
            }
            if expireTime != nil {
                return .subscription
            } else {
                return .lifetime
            }
        }

        func decisionLogDescription(policy: FallbackPolicy, now: Double = Date.now.timeIntervalSince1970) -> String {
            let cacheAgeHours = String(format: "%.1f", max(0, now - fetchTime) / 3600)
            let fetchDescription = Self.logDateString(fetchTime)
            let expirationDescription = expireTime.map(Self.logDateString) ?? "none"
            
            guard active else {
                return "inactive/revoked, fetchTime=\(fetchDescription), expireTime=\(expirationDescription)"
            }
            guard isCache else {
                return "live entitlement, fetchTime=\(fetchDescription), expireTime=\(expirationDescription)"
            }
            
            switch policy {
            case .alwaysKeepPurchase:
                if now > expireTime ?? .infinity {
                    return "cached entitlement expired, cacheAgeHours=\(cacheAgeHours), fetchTime=\(fetchDescription), expireTime=\(expirationDescription), fallbackPolicy=alwaysKeepPurchase"
                } else {
                    return "cached entitlement allowed, cacheAgeHours=\(cacheAgeHours), fetchTime=\(fetchDescription), expireTime=\(expirationDescription), fallbackPolicy=alwaysKeepPurchase"
                }
            case .days(let days):
                let cacheExpiry = fetchTime + Double(days * 24 * 3600)
                let cacheExpiryDescription = Self.logDateString(cacheExpiry)
                if now > expireTime ?? .infinity {
                    return "cached entitlement expired by subscription date, cacheAgeHours=\(cacheAgeHours), fetchTime=\(fetchDescription), expireTime=\(expirationDescription), fallbackPolicy=days(\(days))"
                } else if now > cacheExpiry {
                    return "cached entitlement expired by fallback window, cacheAgeHours=\(cacheAgeHours), fetchTime=\(fetchDescription), cacheExpiry=\(cacheExpiryDescription), expireTime=\(expirationDescription), fallbackPolicy=days(\(days))"
                } else {
                    return "cached entitlement allowed, cacheAgeHours=\(cacheAgeHours), fetchTime=\(fetchDescription), cacheExpiry=\(cacheExpiryDescription), expireTime=\(expirationDescription), fallbackPolicy=days(\(days))"
                }
            case .off:
                return "cached entitlement denied by fallbackPolicy.off, cacheAgeHours=\(cacheAgeHours), fetchTime=\(fetchDescription), expireTime=\(expirationDescription)"
            }
        }
        
        init(_ transaction:StoreKit.Transaction){
            if transaction.revocationDate != nil {
                active = false
            }
            self.offerType = transaction.offerType
            self.ownershipType = OwnershipType(transaction.ownershipType)
            self.fetchTime = Date().timeIntervalSince1970
            self.expireTime = transaction.expirationDate?.timeIntervalSince1970
            self.isCache = false
            var cachedSnapshot = self
            cachedSnapshot.isCache = true
            Self.store.save(cachedSnapshot, for: transaction.productID)
        }
        static func load(_ productId:String)->PurchaseInfo?{
            Self.store.load(productId)
        }
        static func remove(_ productId:String){
            store.remove(productId)
        }
        
        private static func logDateString(_ timeInterval: Double) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return formatter.string(from: Date(timeIntervalSince1970: timeInterval))
        }
    }
}
extension SGProduct.PurchaseInfo: CustomStringConvertible {
    public var description: String {
        let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter
        }()

        let fetchDate = Date(timeIntervalSince1970: fetchTime)
        let fetchDateString = dateFormatter.string(from: fetchDate)

        let expireDateString: String
        if let expireTime = expireTime {
            let expireDate = Date(timeIntervalSince1970: expireTime)
            expireDateString = dateFormatter.string(from: expireDate)
        } else {
            expireDateString = "N/A"
        }
        if #available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, visionOS 1.0, *) {
            return """
        
        active: \(active)
        purchased: \(hasPurchased)
        isCache: \(isCache)
        offerType: \(offerType?.localizedDescription ?? "Unknown")
        ownershipType: \(ownershipType?.rawValue ?? "Unknown")
        fetchTime: \(fetchDateString)
        expireTime: \(expireDateString)
        
        """
        } else {
            
           return """
        
        active: \(active)
        isCache: \(isCache)
        offerType: \(offerType?.rawValue ?? -1)
        ownershipType: \(ownershipType?.rawValue ?? "Unknown")
        fetchTime: \(fetchDateString)
        expireTime: \(expireDateString)
        
        """
        }
    }
}
