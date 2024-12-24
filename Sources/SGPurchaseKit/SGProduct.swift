//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 21/12/24.
//

import Foundation
import StoreKit
public struct SGProduct:Hashable{
    let productId:String
    let group:String
    var purchased = false
    public let product:Product
    init(productId:String, group:String,product:Product,purchased:Bool = false) {
        self.productId = productId
        self.group = group
        self.product = product
        self.purchased = purchased
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(productId)
    }
}

/// The offline policy for a storeKit purchase.
public enum OfflinePolicy{
    /// Call ``SGPurchases.shared.checkGroupStatus(_:)`` will immediately be false  if no internet connection instead of throwing the error.
    case off
    
    /// Call ``SGPurchases.shared.checkGroupStatus`` will throw an error if no internet connection in specified days then expired.
    case days(Int)
}
