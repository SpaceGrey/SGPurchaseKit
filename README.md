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
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PurchaseGroup1</key>
    <array>
        <dict>
            <key>id</key>
            <string>com.item1.year</string>
            <key>display</key>
            <true/>
        </dict>
        <dict>
            <key>id</key>
            <string>com.item1.lifetime</string>
            <key>display</key>
            <false/>
        </dict>
    </array>

    <key>PurchaseGroup2</key>
    <array>
        <dict>
            <key>id</key>
            <string>com.item2.year</string>
            <key>display</key>
            <true/>
        </dict>
    </array>
</dict>
</plist>
```

1. The root dict key is the purchase group name.
2. Each group has an array of products.
3. Each product is a dict containing the id and a boolean to decide if it should be provided to users when calling `getProducts`.

### Init Your Products

In your app's UIApplication Delegate or init of `App` struct in SwiftUI, call `initItems` and set other parameters.

```swift
let purchaseListURL = Bundle.main.url(forResource: "PurchaseItems", withExtension: "plist")!
SGPurchases.initItems(from: purchaseListURL)
SGPurchases.fallbackPolicy = .days(4)
SGPurchases.enableLog = true
//by setting default group, you can emit the group parameter in following methods.
SGPurchases.defaultGroup = "PurchaseGroup1"
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

If you set the `forDisplayOnly`, it will remove the product whose plist display property equals to NO.

```swift
packages = await SGPurchases.shared.getProducts("PurchaseGroup1",forDisplayOnly:true)
```

### Make a Purchase

Call `SGPurchases.shared.purchase` and pass the selected `SGProduct`

```swift
let transaction = try? await SGPurchases.shared.purchase(c)
let result = await SGPurchases.shared.checkGroupStatus("PurchaseGroup1") // check the group status after purchase.
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


### SwiftUI Integration

`SGPurchaseKit` ships with a convenience `ViewModifier` and environment value so that your SwiftUI views automatically stay in sync with purchase state.

```swift
ContentView()
    .injectPurchaseStatus()          // Injects PurchaseStatus using SGPurchases.defaultGroup
```

Inside any descendant view:

```swift
@Environment(\.purchaseStatus) private var status

if status.defaultGroupStatus == true {
    // User has purchased the default group
}

if status["video"] {
    // User has purchased the "video" group
}
```

`purchaseStatus` is a `PurchaseStatus` value that contains all groups:

* `defaultGroupStatus: Bool?` — purchase status for `SGPurchases.defaultGroup` (or `nil` when not set).
* `subscript(group: String) -> Bool` — random-access to any group by its name.

The library broadcasts an updated `PurchaseStatus` whenever a transaction is finished or remotely updated, so the UI refreshes automatically without additional glue code.
