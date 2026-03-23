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
    private var plistModels: [PlistModel] = []
    private var initTask: Task<Void, Never>? = nil
    @MainActor
    var needReload:Bool{
        return items.filter{$0.product == nil}.count > 0 || items.isEmpty
    }
    func initItems(from url: URL) {
        Logger.log("Initializing purchase items from \(url.lastPathComponent)")
        initTask = Task.detached {
            // Load plist file from url
            guard let data = try? Data(contentsOf: url) else {
                Logger.log("Failed to load purchase plist from \(url.path)")
                assertionFailure("Failed to load plist file from \(url)")
                return
            }
            guard
                let list = try? PropertyListDecoder().decode([String:[PlistModel.PlistItem]].self, from: data)
            else {
                Logger.log("Failed to parse purchase plist at \(url.path)")
                assertionFailure("Failed to parse plist file")
                return
            }
            let model = list.map{key,value in
                PlistModel(groupName:key, items:value)
            }
            await MainActor.run{
                self.plistModels = model
            }
            Logger.log("Initialized purchase groups: \(model.map(\.groupName).sorted().joined(separator: ", "))")
        }
    }
    func loadItems() async {
        await initTask?.value
        guard await needReload else {
            return
        }
        // Load products from purchase id
        for model in await plistModels {
            let key = model.groupName
            let value = model.stringItems
            let products: [Product]
            do {
                products = try await Product.products(for: value)
            } catch {
                Logger.log("Failed to load StoreKit products for group \(key): \(error.localizedDescription)")
                products = []
            }
            let missingProductIDs = value.filter { productID in
                products.first { $0.id == productID } == nil
            }
            if !missingProductIDs.isEmpty {
                Logger.log("StoreKit product metadata missing for group \(key): \(missingProductIDs.joined(separator: ", "))")
            }
            for productID in value {
                let p = SGProduct(productId: productID, group: key)
                p.product = products.first{$0.id == productID}
                let _ = await MainActor.run{
                    items.remove(p)
                    items.insert(p)
                }
                if p.product != nil {
                    Logger.log("Group \(key) product metadata loaded for \(productID)")
                } else {
                    Logger.log("Group \(key) product metadata unavailable for \(productID)")
                }
            }
        }
    }
    @MainActor
    func updateProductStatus(_ transaction: StoreKit.Transaction) async {
        await loadItems()
        let id = transaction.productID
        let item = items.first { $0.productId == id }
        guard let product = item else {
            Logger.log("Received transaction for unknown product id \(id); check PurchaseItems.plist mappings")
            return
        }
        product.purchaseInfo = SGProduct.PurchaseInfo(transaction)
        Logger.log("product: \(product.productId), status: \(String(describing: product.purchaseInfo))")
        
        
    }
    
    func getProducts(_ group: String,forDisplayOnly:Bool) async -> [SGProduct] {
        await loadItems()
        let model = await plistModels.first{$0.groupName == group}
        var items = await Array(self.items)
        items = items.filter { $0.group == group && (model?.checkDisplay(of:$0) ?? true || !forDisplayOnly) }
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
        let groupItems = await getProducts(group,forDisplayOnly:false)
        let purchasedItems = groupItems.filter {$0.purchaseInfo?.hasPurchased ?? false}
        if !purchasedItems.isEmpty {
            Logger.log("✅group purchased with \(purchasedItems.map(\.productId).joined(separator: " && "))")
            return true
        } else {
            Logger.log("Group \(group) not purchased. \(groupDiagnostics(groupItems))")
            return false
        }
    }
    @MainActor
    func checkGroupPurchaseStatus(_ group: String) async -> SGProduct.PurchaseStatus?{
        let groupItems = await getProducts(group,forDisplayOnly:false)
        let purchases = groupItems.compactMap(\.purchaseInfo).compactMap(\.purchaseStatus)
        if purchases.contains(.lifetime) {
            Logger.log("Group \(group) purchase status resolved as lifetime")
            return .lifetime
        }
        if purchases.contains(.subscription) {
            Logger.log("Group \(group) purchase status resolved as subscription")
            return .subscription
        }
        if purchases.contains(.trail) {
            Logger.log("Group \(group) purchase status resolved as trail")
            return .trail
        }
        Logger.log("Group \(group) purchase status resolved as nil. \(groupDiagnostics(groupItems))")
        return nil
    }
    @MainActor
    func removeCache(){
        items.forEach{$0.removeCache()}
    }
    
    private func groupDiagnostics(_ groupItems: [SGProduct]) -> String {
        if groupItems.isEmpty {
            return "No products found in this group"
        }
        return groupItems.map { product in
            if let purchaseInfo = product.purchaseInfo {
                return "\(product.productId): \(purchaseInfo.decisionLogDescription(policy: SGPurchases.fallbackPolicy))"
            } else {
                return "\(product.productId): no purchase info cached or loaded"
            }
        }.joined(separator: " | ")
    }
}
