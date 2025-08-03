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
        initTask = Task.detached {
            // Load plist file from url
            guard let data = try? Data(contentsOf: url) else {
                assertionFailure("Failed to load plist file from \(url)")
                return
            }
            guard
                let list = try? PropertyListDecoder().decode([String:[PlistModel.PlistItem]].self, from: data)
            else {
                assertionFailure("Failed to parse plist file")
                return
            }
            let model = list.map{key,value in
                PlistModel(groupName:key, items:value)
            }
            await MainActor.run{
                self.plistModels = model
            }
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
            let products = (try? await Product.products(for: value)) ?? []
            for productID in value {
                let p = SGProduct(productId: productID, group: key)
                p.product = products.first{$0.id == productID}
                let _ = await MainActor.run{
                    items.remove(p)
                    items.insert(p)
                }
                Logger.log("group:\(key) product: \(productID) loaded")
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
        let purchasedItems = await getProducts(group,forDisplayOnly:false).filter {$0.purchaseInfo?.hasPurchased ?? false}
        if !purchasedItems.isEmpty {
            Logger.log("✅group purchased with \(purchasedItems.map(\.productId).joined(separator: " && "))")
            return true
        } else {
            return false
        }
    }
    @MainActor
    func removeCache(){
        items.forEach{$0.removeCache()}
    }
    
    /// 返回所有分组名称
    @MainActor
    func allGroups() async -> [String] {
        await initTask?.value
        return plistModels.map { $0.groupName }
    }
}

