import Foundation
import StoreKit
@MainActor
public class SGPurchases{
    public enum StoreError: Error {
        case failedVerification
        case productNotLoaded
    }
    public static let shared = SGPurchases()
    public static nonisolated(unsafe) var fallbackPolicy = FallbackPolicy.off
    public static nonisolated(unsafe) var enableLog = true
    /// Optional custom logger. Receives a preformatted message with "[SGPurchaseKit]" prefix.
    public static nonisolated(unsafe) var logHandler: ((String) -> Void)? = nil
    /// Set the default purchase group, and you don't need to pass the group when retrieve the items and check purchase status.
    public static nonisolated(unsafe) var defaultGroup:String?
    private static var productManager = SGProductManager()
    var updateListenerTask: Task<Void, Error>? = nil
    
    private init(){
        // Listen for transactions
        Logger.log("Starting transaction updates listener")
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
            Logger.log("Transaction.updates listener is active")
            //iterate through any transactions that don't come from a direct call to 'purchase()'
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    Logger.log("Received transaction update for \(transaction.productID)")
                    await Self.productManager.updateProductStatus(transaction)
                    await transaction.finish()
                    Logger.log("Finished transaction update for \(transaction.productID)")
                case .unverified(let transaction, let error):
                    Logger.log("Transaction update failed verification for \(transaction.productID): \(error.localizedDescription)")
                }
            }
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
        Logger.log("Starting purchase for \(sgProduct.productId)")
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
            Logger.log("Purchase finished for \(sgProduct.productId)")
            
            return transaction
        case .userCancelled:
            Logger.log("Purchase cancelled by user for \(sgProduct.productId)")
            return nil
        case .pending:
            Logger.log("Purchase pending for \(sgProduct.productId)")
            return nil
        default:
            Logger.log("Purchase returned an unknown result for \(sgProduct.productId)")
            return nil
        }
        
    }
    
    /// Check if a group is purchased, config the offline policy in ``SGPurchases/fallbackPolicy``
    /// - Parameter group: The group to check
    public func checkGroupStatus(_ g:String? = nil) async -> Bool{
        let group = g ?? Self.defaultGroup
        assert(group != nil, "No Group Detected, Config the defaultGroup or pass the group name")
        Logger.log("Checking group purchase boolean for \(group!)")
        await updateCustomerProductStatus()
        let result = await Self.productManager.checkGroupStatus(group!)
        Logger.log("Finished checking group purchase boolean for \(group!): \(result)")
        return result
    }
    
    /// Check the group purchaseStatus, config the offline policy in ``SGPurchases/fallbackPolicy``
    /// - Parameter group: The group to check
    public func checkGroupPurchaseStatus(_ g:String? = nil) async -> SGProduct.PurchaseStatus?{
        let group = g ?? Self.defaultGroup
        assert(group != nil, "No Group Detected, Config the defaultGroup or pass the group name")
        Logger.log("Checking group purchase status for \(group!)")
        await updateCustomerProductStatus()
        let result = await Self.productManager.checkGroupPurchaseStatus(group!)
        Logger.log("Finished checking group purchase status for \(group!): \(String(describing: result))")
        return result
    }
    
    
    /// Restore purchase
    ///
    /// The function will sync the data with App Store, if there's remote transaction, the listener will update the user's purchase automatically.
    public func restorePurchase() async {
        Logger.log("Starting AppStore.sync() restore flow")
        do {
            try await AppStore.sync()
            Logger.log("AppStore.sync() restore flow completed")
        } catch {
            Logger.log("AppStore.sync() restore flow failed: \(error.localizedDescription)")
        }
    }
    
    func isTransactionCurrentlyValid(_ transaction: Transaction) -> Bool {
        if transaction.revocationDate != nil {
            return false
        }
        guard let expirationDate = transaction.expirationDate else {
            return true
        }
        return expirationDate > Date()
    }
    
    
    func updateCustomerProductStatus() async {
        Logger.log("Refreshing current entitlements")
        var verifiedCount = 0
        var unverifiedCount = 0
        var latestFallbackCount = 0
        var currentProductIDs = Set<String>()
        //iterate through all the user's purchased products
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                verifiedCount += 1
                currentProductIDs.insert(transaction.productID)
                Logger.log("Found current entitlement for \(transaction.productID)")
                // since we only have one type of producttype - .nonconsumables -- check if any storeProducts matches the transaction.productID then add to the purchasedCourses
                await SGPurchases.productManager.updateProductStatus(transaction)
            case .unverified(let transaction, let error):
                unverifiedCount += 1
                Logger.log("Current entitlement failed verification for \(transaction.productID): \(error.localizedDescription)")
            }
        }
        let productIDs = Set(await Self.productManager.getProductIDs())
        let latestFallbackIDs = productIDs.subtracting(currentProductIDs).sorted()
        for productID in latestFallbackIDs {
            guard let result = await Transaction.latest(for: productID) else {
                Logger.log("No latest transaction found for \(productID)")
                continue
            }
            switch result {
            case .verified(let transaction):
                guard isTransactionCurrentlyValid(transaction) else {
                    Logger.log("Latest transaction for \(productID) is not currently valid")
                    continue
                }
                latestFallbackCount += 1
                Logger.log("Using latest transaction fallback for \(productID)")
                await SGPurchases.productManager.updateProductStatus(transaction)
            case .unverified(let transaction, let error):
                Logger.log("Latest transaction failed verification for \(transaction.productID): \(error.localizedDescription)")
            }
        }
        if verifiedCount == 0 {
            Logger.log("StoreKit returned no current entitlements")
        }
        Logger.log("Finished refreshing current entitlements. verified=\(verifiedCount), unverified=\(unverifiedCount), latestFallback=\(latestFallbackCount)")
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
        Logger.log("Refreshing purchase cache")
        Self.productManager.removeCache()
        Task{
            await updateCustomerProductStatus()
        }
    }
}
