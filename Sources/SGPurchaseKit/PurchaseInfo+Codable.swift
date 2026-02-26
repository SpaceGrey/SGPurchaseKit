//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 11/12/25.
//

import Foundation
import StoreKit

extension SGProduct.PurchaseInfo {
    enum CodingKeys: String, CodingKey {
        case fetchTime
        case offerType
        case active
        case expireTime
        case isCache
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Use defaults for missing keys to keep old cache backward compatible.
        fetchTime = try container.decode(Double.self, forKey: .fetchTime)
        active = try container.decode(Bool.self, forKey: .active)
        isCache = try container.decode(Bool.self, forKey: .isCache)
        expireTime = try container.decodeIfPresent(Double.self, forKey: .expireTime)
        
        // Backward compatible: default to nil if offerType is missing or invalid.
        if let rawValue = try? container.decodeIfPresent(Int.self, forKey: .offerType) {
            offerType = Transaction.OfferType(rawValue: rawValue)
        } else {
            offerType = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(fetchTime, forKey: .fetchTime)
        try container.encode(active, forKey: .active)
        try container.encode(isCache, forKey: .isCache)
        try container.encodeIfPresent(expireTime, forKey: .expireTime)
        
        // 将 offerType 编码为其 rawValue
        if let offerType = offerType {
            try container.encode(offerType.rawValue, forKey: .offerType)
        }
    }
}
