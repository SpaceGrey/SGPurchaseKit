import Foundation
import StoreKit
import KeychainSwift
@MainActor
public class SGPurchases{
    public enum StoreError: Error {
        case failedVerification
        case productNotLoaded
    }
    public static let shared = SGPurchases()
    public static nonisolated(unsafe) var fallbackPolicy = FallbackPolicy.off
    public static nonisolated(unsafe) var enableLog = true
    /// Set the default purchase group, and you don't need to pass the group when retrieve the items and check purchase status.
    public static nonisolated(unsafe) var defaultGroup:String?
    private static var productManager = SGProductManager()
    var updateListenerTask: Task<Void, Error>? = nil
    
    private init(){
        // Listen for transactions
        updateListenerTask = listenForTransactions()
    }
        
    /// Load purchase items using purchase id from a plist file.
    ///
    /// The structure of plist should be like this:
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
        Self.productManager.initItems(from: url)
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
                    await Self.productManager.updateProductStatus(transaction)
                    await transaction.finish()
                } catch {
                    Logger.log("Transaction failed verification")
                }
            }
            // Diff refresh
            // Notify listeners that purchase status changed
            await self.postProductStatusNotification()
        }
    }
    /// Purchase a product
    /// - Parameter sgProduct: The product to purchase
    /// - Returns: The current transaction if succeed, nil if user cancelled or pending
    ///
    /// You don't need to use the output   `Transaction`, you can use `checkGroupStatus` after `purchase` instead.
    @discardableResult
    public func purchase(_ sgProduct: SGProduct) async throws -> Transaction? {
        //make a purchase request - optional parameters available
        
        guard let product = sgProduct.product else {
            throw StoreError.productNotLoaded
        }
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
    
    /// Check if a group is purchased, config the offline policy in ``SGPurchases/fallbackPolicy``
    /// - Parameter group: The group to check
    public func checkGroupStatus(_ g:String? = nil) async -> Bool{
        let group = g ?? Self.defaultGroup
        assert(group != nil, "No Group Detected, Config the defaultGroup or pass the group name")
        await updateCustomerProductStatus()
        return await Self.productManager.checkGroupStatus(group!)
    }
    
    /// Restore purchase
    ///
    /// The function will sync the data with App Store, if there's remote transaction, the listener will update the user's purchase automatically.
    public func restorePurchase() async {
        try? await AppStore.sync()
    }
    
    
    func updateCustomerProductStatus() async {
        //iterate through all the user's purchased products
        for await result in Transaction.currentEntitlements {
            do {
                //again check if transaction is verified
                let transaction = try checkVerified(result)
                // since we only have one type of producttype - .nonconsumables -- check if any storeProducts matches the transaction.productID then add to the purchasedCourses
                await SGPurchases.productManager.updateProductStatus(transaction)
            } catch {
                Logger.log("Transaction failed verification")
            }
        }
        //Reload
        // Notify listeners that purchase status changed
        await postProductStatusNotification()
    }
    
    func postProductStatusNotification() async{
        // Broadcast the latest purchase status for all groups
        let groups = await Self.productManager.allGroups()
        var statuses: [String: Bool] = [:]
        for group in groups {
            let purchased = await Self.productManager.checkGroupStatus(group)
            statuses[group] = purchased
        }
        let purchaseStatus = PurchaseStatus(groupStatuses: statuses)
        NotificationCenter.default.post(name: .purchaseStatusUpdated, object:nil, userInfo:["status": purchaseStatus])
    }
    
    /// Get products by group
    /// - Parameter group: The group to get
    /// - Parameter forDisplayOnly: if only load the items that you set display to true in the plist file.
    /// The products will be sorted by price.
    public func getProducts(_ g:String? = nil,forDisplayOnly:Bool = true) async -> [SGProduct]{
        let group = g ?? Self.defaultGroup
        assert(group != nil, "No Group Detected, Config the defaultGroup or pass the group name")
        return await Self.productManager.getProducts(group!, forDisplayOnly: forDisplayOnly)
    
    }
    ///Remove all product purchases status cache and retrieve the latest status
    public func refreshCache(){
        Self.productManager.removeCache()
        Task{
            await updateCustomerProductStatus()
        }
    }
}

