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
    private var initTask: Task.Handle<Void, Never>? = nil
    @MainActor
    var needReload:Bool{
        return items.filter{$0.product == nil}.count > 0 || items.isEmpty
    }
    func initItems(from url: URL) {
        initTask = Task.detached {
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
        await initTask?.value
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
    func updateProductStatus(_ transaction: StoreKit.Transaction) async {
        await loadItems()
        let id = transaction.productID
        let item = items.first { $0.productId == id }
        guard let product = item else {
            return
        }
        product.purchaseInfo = SGProduct.PurchaseInfo(transaction)
        print("product: \(product.productId), status: \(product.purchaseInfo)")
        
        
    }
    func getProducts(_ group: String) async -> [SGProduct] {
        await loadItems()
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
        let purchasedItems = await getProducts(group).filter {$0.purchaseInfo?.hasPurchased ?? false}
        if !purchasedItems.isEmpty {
            print("✅group purchased with \(purchasedItems.map(\.productId).joined(separator: " && "))")
            return true
        } else {
            return false
        }
    }
    func removeCache(){

    }
}
