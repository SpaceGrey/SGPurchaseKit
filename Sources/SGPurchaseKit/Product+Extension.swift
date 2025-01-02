//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 21/12/24.
//

import Foundation
import StoreKit
import SwiftUICore
public extension StoreKit.Product {
    /// Calculates the price per month for a subscription product.
    /// - Returns: The price per month as a `Decimal`, or `nil` if the product is not a subscription.
    var pricePerMonth: Decimal? {
        guard let subscription = subscription else {
            return nil // Return nil if the product is not a subscription.
        }
        
        // Extract the price and the subscription period.
        let price = price // The total price of the subscription.
        let period = subscription.subscriptionPeriod
        
        // Convert the subscription period into months.
        let months: Int
        switch period.unit {
        case .day:
            months = period.value / 30 // Approximate days to months.
        case .week:
            months = period.value * 7 / 30 // Approximate weeks to months.
        case .month:
            months = period.value
        case .year:
            months = period.value * 12
        @unknown default:
            return nil
        }
        
        // Avoid division by zero.
        guard months > 0 else {
            return nil
        }
        
        // Calculate the price per month.
        let pricePerMonth = price / Decimal(months)
        return pricePerMonth
    }
}

