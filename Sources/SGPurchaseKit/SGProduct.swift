//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 21/12/24.
//

import Foundation
import StoreKit
public class SGProduct:Hashable,Equatable{
    let productId:String
    let group:String
    var purchaseInfo:PurchaseInfo? = nil
    public var product:Product? = nil
    init(productId:String, group:String) {
        self.productId = productId
        self.group = group
        self.purchaseInfo = PurchaseInfo.load(productId)
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(productId)
    }
    public static func == (lhs: SGProduct, rhs: SGProduct) -> Bool {
        return lhs.productId == rhs.productId
    }
}

/// The policy for when there’s no purchase or can not retrieve purchase info
public enum FallbackPolicy{
    /// disable fallback, directly return false
    case off
    /// use cache data to keep purchase for specific days.
    case days(Int)
}

