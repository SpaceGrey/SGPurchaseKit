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
    init(productId:String, group:String,product:Product){
        self.productId = productId
        self.group = group
        self.product = product
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(productId)
    }
}
