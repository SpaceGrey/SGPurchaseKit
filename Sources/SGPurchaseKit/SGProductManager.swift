//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 1/1/25.
//

import Foundation
import StoreKit

class SGProductManager {
    @MainActor
    private var items: Set<SGProduct> = []
    @MainActor
    private var purchaseItemsString: [String: [String]] = [:]
    func initItems(from url: URL) {
        Task.detached {
            // Load plist file from url
            guard let data = try? Data(contentsOf: url) else {
                assertionFailure("Failed to load plist file from \(url)")
                return
            }
            guard
                let items = try? PropertyListSerialization.propertyList(
                    from: data, options: [], format: nil) as? [String: [String]]
            else {
                assertionFailure("Failed to parse plist file")
                return
            }
            await MainActor.run{
                self.purchaseItemsString = items
            }
        }
    }
    func loadItems() async {
        guard await needReload else {
            return
        }
        // Load products from purchase id
        for (key, value) in await purchaseItemsString {
            let products = (try? await Product.products(for: value)) ?? []
            for product in products {
                let p = SGProduct(productId: product.id, group: key)
                p.product = product
                let _ = await MainActor.run{
                    items.insert(p)
                }
                print("group:\(key) product: \(product.id) loaded")
            }
        }
    }
    @MainActor
    func updateProductStatus(_ transaction: StoreKit.Transaction) {
        let id = transaction.productID
        let item = items.first { $0.productId == id }
        guard let product = item else {
            return
        }
        product.purchaseInfo = SGProduct.PurchaseInfo(transaction)
        print("product: \(product.productId), status: \(product.purchaseInfo)")
        
        
    }
    @MainActor
    var needReload:Bool{
        return items.filter{$0.product == nil}.count > 0 || items.isEmpty
    }
    func getProducts(_ group: String) async -> [SGProduct] {
        if await needReload {
            await loadItems()
        }
        var items = await Array(self.items)
        items = items.filter { $0.group == group}
        items.sort{l, r in
            guard let l = l.product, let r = r.product else {
                return l.productId < r.productId
            }
            return l.price < r.price
        }
        return items
    }
    @MainActor
    func checkGroupStatus(_ group: String) async -> Bool{
        return await !getProducts(group).filter {$0.purchaseInfo?.hasPurchased ?? false}.isEmpty
    }
}
