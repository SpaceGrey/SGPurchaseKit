import Foundation
import StoreKit
import KeychainSwift
@MainActor
public class SGPurchases{
    public enum StoreError: Error {
        case failedVerification
    }
    static var purchaseItems:Set<SGProduct> = []
    static var purchaseItemsString:[String:[String]] = [:]
    public static let shared = SGPurchases()
    public static var offlinePolicy = OfflinePolicy.off
    var updateListenerTask: Task<Void, Error>? = nil
    let expired:Bool
    let lastCheckedTime = "SGPurchaseKitExpiredDate"
    private let keyChain = KeychainSwift()
    private init(){
        // Listen for transactions
        print(Self.offlinePolicy)
        switch Self.offlinePolicy {
        case .off:
            expired = true
        case .days(let d):
            if let last = keyChain.get(lastCheckedTime),let lastCheckedDate = Double(last) {
                let expiredDate = lastCheckedDate + Double(d * 24 * 60 * 60)
                expired = Date().timeIntervalSince1970 > expiredDate
            } else {
                expired = true
            }
        }
        updateListenerTask = listenForTransactions()
    }
        
    /// Load purchase items using purchase id from a plist file.
    ///
    /// The structure of plist is like this:
    /// ```
    /// {
    ///    "live photo":[
    ///    "com.sg.livephoto1",
    ///    "com.sg.livephoto2",
    ///     ],
    ///    "video":[
    ///    "com.sg.video1",
    ///     ],
    ///}
    /// ```
    public static func initItems(from url:URL){
        Task.detached{
            // Load plist file from url
            guard let data = try? Data(contentsOf: url) else{
                assertionFailure("Failed to load plist file from \(url)")
                return
            }
            guard let items = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String:[String]] else{
                assertionFailure("Failed to parse plist file")
                return
            }
            await MainActor.run{
                purchaseItemsString = items
                
            }
            try? await loadItems()
        }
    }
    /// load purchase items from the plist file that you passed in `initItems(from:)`
    ///
    /// in case the `initItems` load failed, you can call this function to reload the items.
    public static func loadItems() async throws {
        // Load products from purchase id
        if purchaseItemsString.isEmpty{
            assertionFailure("purchaseItemsString is empty")
            return
        }
        if Self.purchaseItems.isEmpty{
            var tempPurchaseItems:Set<SGProduct> = []
            for (key, value) in purchaseItemsString{
                let products = try await Product.products(for: value)
                if products.isEmpty{
                    throw StoreKitError.networkError(URLError(.cannotConnectToHost))
                }
                for product in products{
                    tempPurchaseItems.insert(SGProduct(productId: product.id, group: key,product: product))
                    print("group:\(key) product: \(product.id) loaded")
                }
            }
            if Self.purchaseItems.isEmpty{
                Self.purchaseItems = tempPurchaseItems
            }
        }
    }
    
    //Generics - check the verificationResults
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //check if JWS passes the StoreKit verification
        switch result {
        case .unverified:
            //failed verificaiton
            throw StoreError.failedVerification
        case .verified(let signedType):
            //the result is verified, return the unwrapped value
            return signedType
        }
    }
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            //iterate through any transactions that don't come from a direct call to 'purchase()'
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    print("remote transaction \(transaction.productID)")
                    await self.updateCustomerProductStatus()
                    //Always finish a transaction
                    await transaction.finish()
                } catch {
                    //storekit has a transaction that fails verification, don't delvier content to the user
                    print("Transaction failed verification")
                }
            }
        }
    }
    /// Purchase a product
    /// - Parameter sgProduct: The product to purchase
    /// - Returns: The current transaction if succeed, nil if user cancelled or pending
    ///
    /// You don't need to use the output   `Transaction`, you can use `checkGroupStatus` after `purchase` instead.
    public func purchase(_ sgProduct: SGProduct) async throws -> Transaction? {
        //make a purchase request - optional parameters available
        let product = sgProduct.product
        let result = try await product.purchase()
        
        // check the results
        switch result {
        case .success(let verificationResult):
            //Transaction will be verified for automatically using JWT(jwsRepresentation) - we can check the result
            let transaction = try checkVerified(verificationResult)
            
            //the transaction is verified, deliver the content to the user
            await updateCustomerProductStatus()
            
            //always finish a transaction - performance
            await transaction.finish()
            
            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
        
    }
    
    /// Check if a group is purchased, config the offline policy in ``SGPurchases.offlinePolicy``
    /// - Parameter group: The group to check
    public func checkGroupStatus(_ group:String) async throws -> Bool{
        if Self.purchaseItems.isEmpty{
            do {
                try await SGPurchases.loadItems()
            }
            catch {
                if let e = error as? StoreKitError, case .networkError(let urlError) = e {
                    if !expired {
                        throw error
                    }
                }
            }
        }
        await updateCustomerProductStatus()
        let result = Self.purchaseItems.contains(where: { $0.group == group && $0.purchased == true})
        print("group \(group) purchased \(result)")
        return result
    }
    
    /// Restore purchase
    ///
    /// The function will sync the data with App Store, if there's remote transaction, the listener will update the user's purchase automatically.
    public func restorePurchase()async{
        try? await AppStore.sync()
    }
    
    
    func updateCustomerProductStatus() async {
        var purchasedIDs:[String] = []
        //iterate through all the user's purchased products
        for await result in Transaction.currentEntitlements {
            do {
                //again check if transaction is verified
                let transaction = try checkVerified(result)
                // since we only have one type of producttype - .nonconsumables -- check if any storeProducts matches the transaction.productID then add to the purchasedCourses
                print("new transaction \(transaction.productID)")
                purchasedIDs.append(transaction.productID)
            } catch {
                print("Transaction failed verification")
            }
        }
        if !purchasedIDs.isEmpty{
            keyChain.set(String(Date().timeIntervalSince1970), forKey: lastCheckedTime)
        } else {
            keyChain.delete(lastCheckedTime)
        }
        var newItems:Set<SGProduct> = []
        for item in Self.purchaseItems{
            if purchasedIDs.contains(item.productId){
                newItems.insert(SGProduct(productId: item.productId, group: item.group, product: item.product, purchased: true))
            } else {
                newItems.insert(SGProduct(productId: item.productId, group: item.group, product: item.product, purchased: false))
            }
        }
        Self.purchaseItems = newItems
    }
    
    /// Get products by group
    /// - Parameter group: The group to get
    ///
    /// The products will be sorted by price
    public func getProducts(_ group:String) async throws -> [SGProduct]{
        if Self.purchaseItems.isEmpty{
            try await SGPurchases.loadItems()
        }
        var items = Array(Self.purchaseItems.filter({$0.group == group}))
        items.sort { l, r in
            l.product.price < r.product.price
        }
        return items
    }
}

