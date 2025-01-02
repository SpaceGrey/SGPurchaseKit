//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 21/12/24.
//

import Foundation
import StoreKit
public class SGProduct:Hashable,Equatable{
    /// the product id you set in App Store Connect
    let productId:String
    /// the group you set in your init plist file.
    let group:String
    var purchaseInfo:PurchaseInfo? = nil
    /// associated StoreKit product
    public var product:Product? = nil
    init(productId:String, group:String) {
        self.productId = productId
        self.group = group
        self.purchaseInfo = PurchaseInfo.load(productId)
        if let p = purchaseInfo{
            print("load \(productId) info from cache \(p)")
        }
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(productId)
    }
    public static func == (lhs: SGProduct, rhs: SGProduct) -> Bool {
        return lhs.productId == rhs.productId && lhs.purchaseInfo == rhs.purchaseInfo
    }
    func removeCache(){
        PurchaseInfo.remove(productId)
    }
}

/// The policy for when there’s no purchase(user switch app store account) or can not retrieve purchase info
public enum FallbackPolicy{
    /// disable fallback, directly return no purchase info.
    case off
    /// use cache data to keep purchase for specific days.
    case days(Int)
}


