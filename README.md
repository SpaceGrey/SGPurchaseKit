# SGPurchaseKit

<p>
  <img src="https://img.shields.io/badge/Swift-5.7-orange?logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/SPM-Supported-brightgreen" alt="SPM" />
  <img src="https://img.shields.io/badge/Platforms-iOS%2015%2B%20|%20macOS%2012%2B%20|%20tvOS%2015%2B%20|%20watchOS%208%2B-blue" alt="Platforms" />
</p>

SGPurchaseKit is a simple replacement for RevenueCat using StoreKit2 with the same calling style and fallback support.

## Requirements
- **iOS 15+**
- **macOS 12+**
- **tvOS 15+**
- **watchOS 8+**

## Installation

1. In Xcode, open the project that you want to add this package.
2. From the menu bar, select File > Swift Packages > Add Package Dependency...
3. Paste the [URL](https://github.com/SpaceGrey/SGPurchaseKit.git) for this repository into the search field.
4. Select the `SGPurchaseKit` Library.
5. Follow the prompts for adding the package.

## Quick Start

### Create Your Products Plist

SGPurchase can group your multiple products into groups, and you can directly retrieve the group purchase status.

Firstly you need to create your `.plist` in your target.

The structure is like:

```xml
<plist version="1.0">
<dict>
	<key>PurchaseGroup1</key>
	<array>
		<string>com.item1.year</string>
		<string>com.item1.lifetime</string>
	</array>
	<key>PurchaseGroup2</key>
	<array>
	<string>com.item2.month</string>
	</array>
</dict>
</plist>
```

It will be decoded into `[String:[String]]` dictionary.

### Init Your Products

In your app's UIApplication Delegate or init of `App` struct in SwiftUI, call `initItems` and set other parameters.

```swift
let purchaseListURL = Bundle.main.url(forResource: "PurchaseItems", withExtension: "plist")!
SGPurchases.initItems(from: purchaseListURL)
SGPurchases.fallbackPolicy = .days(4)
SGPurchases.enableLog = true
        
```

### Check Purchase Status

If you want to check the purchase status of a certain group, call `SGPurchases.shared.checkGroupStatus`:

```swift
if await SGPurchases.shared.checkGroupStatus("PurchaseGroup1"){
     //give the user paid content.    
} else {
		//remove content.
}
```

### Display Your Products on Paywall

If you want to get products for certain groups, call `SGPurchases.shared.getProducts`, it returns a `SGProduct` array that contains the StoreKit product. It's sorted by price from low to high by default.

```swift
packages = await SGPurchases.shared.getProducts("PurchaseGroup1")
```

### Make a Purchase

Call `SGPurchases.shared.purchase` and pass the selected `SGProduct`

```swift
 let transaction = try? await SGPurchases.shared.purchase(c)
 let result = await SGPurchases.shared.checkGroupStatus("PurchaseGroup1")//check the group status after purchase.
```

### Restore

Call `SGPurchases.shared.restorePurchases`. You don't need to call restore when you launch the app, the `SGPurchaseKit` automatically listens to the remote transactions and updates the status. 

```swift
await SGPurchases.shared.restorePurchase()
let result = await SGPurchases.shared.checkGroupStatus("PurchaseGroup1")
```

### Fallback Policy

In some situations, like user is offline, or the user switches to a different account. You can choose whether to keep the user's access using cache for specific days, or simply disable the paid content. 

Set it together with the `initItems()`



