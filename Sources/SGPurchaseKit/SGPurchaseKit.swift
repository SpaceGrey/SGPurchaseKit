import Foundation
import StoreKit
@MainActor
public class SGPurchases{
    public enum StoreError: Error {
        case failedVerification
    }
    static var purchaseItems:Set<SGProduct> = []
    var updateListenerTask: Task<Void, Error>? = nil
    static var purchaseItemsString:[String:[String]] = [:]
    public static let shared = SGPurchases()
    private init(){
        // Listen for transactions
        updateListenerTask = listenForTransactions()
    }
        
    /// Load purchase items using purchase id from a plist file.
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
            await loadItems()
        }
    }
    public static func loadItems() async {
        // Load products from purchase id
        if purchaseItemsString.isEmpty{
            assertionFailure("purchaseItemsString is empty")
            return
        }
        if Self.purchaseItems.isEmpty{
            for (key, value) in purchaseItemsString{
                let products = (try? await Product.products(for: value)) ?? []
                for product in products{
                    purchaseItems.insert(SGProduct(productId: product.id, group: key,product: product))
                    print("product \(product.id) loaded")
                }
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
    public func checkGroupStatus(_ group:String) async -> Bool{
        if Self.purchaseItems.isEmpty{
            await SGPurchases.loadItems()
        }
        await updateCustomerProductStatus()
        let result = Self.purchaseItems.contains(where: { $0.group == group && $0.purchased == true})
        print("group \(group) purchased \(result)")
        return result
    }
    public func restorePurchase()async{
        try? await AppStore.sync()
    }
    func updateCustomerProductStatus() async {
        //iterate through all the user's purchased products
        for await result in Transaction.currentEntitlements {
            do {
                //again check if transaction is verified
                let transaction = try checkVerified(result)
                // since we only have one type of producttype - .nonconsumables -- check if any storeProducts matches the transaction.productID then add to the purchasedCourses
                if let oldProduct = Self.purchaseItems.first(where:{$0.productId == transaction.productID}){
                    Self.purchaseItems.remove(oldProduct)
                    var newProduct = oldProduct
                    newProduct.purchased = true
                    Self.purchaseItems.insert(newProduct)
                }
            } catch {
                //storekit has a transaction that fails verification, don't delvier content to the user
                print("Transaction failed verification")
            }
            
        }
    }
    public func getProducts(_ group:String) async -> [SGProduct]{
        if Self.purchaseItems.isEmpty{
            await SGPurchases.loadItems()
        }
        var items = Array(Self.purchaseItems.filter({$0.group == group}))
        items.sort { l, r in
            l.product.price < r.product.price
        }
        return items
    }
}

