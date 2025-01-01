//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 1/1/25.
//

import Foundation
import StoreKit
import KeychainSwift
extension SGProduct{
    public struct PurchaseInfo:Codable,Equatable{
        private static let PREFIX = "SGProduct.PurchaseInfo"
        private static let keyChain = KeychainSwift()
        private var fetchTime:Double
        private var active:Bool = true
        private var expireTime:Double?
        private var isCache:Bool = true
        @MainActor
        var hasPurchased:Bool{
            guard active else {
                return false
            }
            guard isCache else {
                return true
            }
            switch SGPurchases.fallbackPolicy {
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
        init(_ transaction:StoreKit.Transaction){
            if transaction.revocationDate != nil {
                active = false
            }
            self.fetchTime = Date().timeIntervalSince1970
            self.expireTime = transaction.expirationDate?.timeIntervalSince1970
            if let data = try? JSONEncoder().encode(self){
                Self.keyChain.set(data, forKey: "\(Self.PREFIX).\(transaction.productID)")
            }
            self.isCache = false
        }
        static func load(_ productId:String)->PurchaseInfo?{
            if let data = Self.keyChain.getData("\(Self.PREFIX).\(productId)"){
                return try? JSONDecoder().decode(Self.self, from: data)
            }
            return nil
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

        return """
        
        active: \(active)
        isCache: \(isCache)
        fetchTime: \(fetchDateString)
        expireTime: \(expireDateString)
        
        """
    }
}
