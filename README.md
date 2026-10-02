# Botsi iOS SDK Documentation

The Botsi SDK enables seamless in-app purchases and paywall management in iOS applications. This documentation covers the public API methods available for integration.

## Table of Contents
- [Installation](#installation)
- [Migrating from 1.x](#migrating-from-1x)
- [Initialization](#initialization)
- [Profile Management](#profile-management)
- [Product Management](#product-management)
- [Purchase Operations](#purchase-operations)
- [Paywall Management](#paywall-management)
- [Objective-C Bridge](#objective-c-bridge)

## Installation

**Requirements:** iOS 16.0 or later. The SDK uses StoreKit 2 only. Apps that still support iOS 13–15 should stay on SDK 1.x.

Install the SDK with Swift Package Manager. It's the only supported way to add Botsi to your app.

### Swift Package Manager

1. **Open your project in Xcode.**
2. **Add the package.** Choose **File** > **Add Package Dependencies…** and enter the repository URL:

   ```
   https://github.com/BotsiTeam/BotsiSDK-iOS.git
   ```

3. **Choose the version.** Set **Dependency Rule** to **Up to Next Major Version** from **2.0.0**, the latest version, then select **Add Package**.
4. **Add the library.** Add the `Botsi` library to your app target and select **Add Package**.
5. **Import the SDK** in your source files:

   ```swift
   import Botsi
   ```

If you declare dependencies in a `Package.swift` file, add the package:

```swift
.package(url: "https://github.com/BotsiTeam/BotsiSDK-iOS.git", from: "2.0.0")
```

Then add `.product(name: "Botsi", package: "BotsiSDK-iOS")` to your target's dependencies.

### CocoaPods is no longer supported

Botsi is no longer supported through CocoaPods, and new versions aren't published there. CocoaPods itself is winding down: its central repository stops accepting new versions on December 2, 2026. Apps that install an earlier Botsi version through CocoaPods keep building, but they won't get updates.

To move from CocoaPods to Swift Package Manager:

1. Remove the `pod 'Botsi'` line from your `Podfile` and run `pod install`. If Botsi was your only pod, run `pod deintegrate` instead to remove CocoaPods from the project.
2. Add Botsi with [Swift Package Manager](#swift-package-manager), as above.

## Migrating from 1.x

SDK 2.0 calls only the Botsi V2 API, uses StoreKit 2 only and requires iOS 16. Apps that still support iOS 13–15 should stay on 1.x. Existing users keep their Botsi profiles: the SDK reads the profile 1.x saved and keeps its ID.

If you installed 1.x through CocoaPods, switch to Swift Package Manager: 2.0 isn't available through CocoaPods. See [CocoaPods is no longer supported](#cocoapods-is-no-longer-supported).

**Renamed or removed APIs:**

| 1.x | 2.0 |
| --- | --- |
| `Botsi.activate(_:customerUserId:)` | `Botsi.activate(_:appUserId:)` |
| `BotsiConfiguration.set(customerUserIdentifier:)` | `BotsiConfiguration.set(appUserId:)` |
| `BotsiConfiguration.set(profileIdentifier:)` | Removed; it had no effect |
| `BotsiProfile.customerUserId` | `BotsiProfile.appUserId` |
| `BotsiProfile.birthday` | Removed from the profile; still set through `updateProfile(_:)` |
| `BotsiUserProfileInformation(ip:)` | `BotsiUserProfileInformation(ipAddress:)` |
| `BotsiPaywall.sourceProducts` | `BotsiPaywall.products`; the App Store product ID is `product.appStore?.productId` |
| `BotsiPaywall.remoteConfigs`, `revision`, `abTestId` | Removed; the V2 API doesn't return them |
| `BotsiProduct.abTestId`, `BotsiProduct.sk1Product` | Removed |
| `BotsiAccessLevel` / `BotsiSubscription` `store` and `sourceProductId` | Now optional |
| Objective-C `activate:customerUserId:completion:` | `activate:appUserId:completion:` |
| `BotsiObjCProfile.customerUserId` | `BotsiObjCProfile.appUserId` |
| `BotsiObjCPaywall.remoteConfigs`, `revision`, `abTestId` | Removed; `externalId`, `isExperiment`, `aiPricingModelId` and `paywallSessionId` added |

**Behavior changes:**

- **Restore:** `restorePurchases()` syncs with the App Store first, so StoreKit may ask the user to sign in. Call it only from a Restore button. When there's nothing to restore, it returns the profile unchanged rather than throwing, so check `accessLevels`. The SDK still restores automatically, without a prompt, whenever it creates a profile.
- **Signed-in users:** calling `activate(_:)` without an `appUserId` keeps a user you identified earlier. Call `logout()` when the user signs out.
- **Paywall views:** call `logPaywallShown(for:)` within about 24 hours of `getPaywall(from:)`; after that, fetch the paywall again.
- **Promotional offers:** if your app's iOS settings in Botsi can't sign offers, the purchase fails with `BotsiError.promoOfferNotConfigured` instead of going ahead at full price.
- **Errors:** errors returned by Botsi arrive as `BotsiError.apiError(status:code:message:)`.

## Initialization

### `activate(_ key:)`
```swift
static func activate(_ key: String) async throws
```

Activates and initializes the Botsi SDK with your public key.

**Example:**
```swift
do {
    try await Botsi.activate("your_api_key")
    // SDK is now initialized and ready for use
} catch let error as BotsiError {
    print("Failed to initialize Botsi SDK: \(error.localizedDescription)")
} catch {
    print("Unknown error")
}
```

### `activate(_ key:appUserId:)`
```swift
static func activate(_ key: String, appUserId: String?) async throws
```

Activates and initializes the Botsi SDK with your public key and optionally links it to a specific user in your system.

**Parameters:**
- `key`: Your app's public SDK key from the Botsi dashboard. Never put your app secret key in an app.
- `appUserId`: Optional identifier for the user in your system. If provided, the SDK profile will be linked to this user immediately upon activation. Botsi finds the user's existing profile when it already knows this ID.

**Example:**
```swift
do {
    // Activate with user ID for immediate user linking
    try await Botsi.activate("your_public_sdk_key", appUserId: "user_12345")
    // SDK is now initialized and linked to the specified user
} catch let error as BotsiError {
    print("Failed to initialize Botsi SDK: \(error.localizedDescription)")
} catch {
    print("Unknown error")
}
```

### `isInitialized`
```swift
static var isInitialized: Bool { get async }
```

Checks if the Botsi SDK has been properly initialized.

**Returns:**
- `Bool`: `true` if the SDK has been initialized, `false` otherwise.

**Example:**
```swift
let initialized = await Botsi.isInitialized
if initialized {
    // SDK is ready to use
} else {
    // SDK needs to be initialized
}
```

### `identify(_ userId: String)`
```swift
static func identify(_ userId: String) async throws
```

Links the SDK session to a specific user in your own system.
If you didn’t provide a user ID when initializing the SDK, you can call `.identify()` at any point—most often right after the user signs up or logs in, moving from an anonymous session to an authenticated one.

Parameter userId: The unique identifier for the user in your system.

**Example:**
```swift
do {
    let currentUserId = "user_12345"
    try await Botsi.identify(currentUserId)
    // The SDK session is now linked to the authenticated user
} catch let error as BotsiError {
    print("Failed to identify user: \(error.localizedDescription)")
} catch {
    print("Unexpected error during user identification: \(error)")
}
```

### `logout()`
```swift
static func logout() async throws
```

Ends the current user session and reverts the SDK to an anonymous state.

Calling `.logout()` removes any stored user identifier and clears session-specific data, so subsequent calls behave as if no user is signed in. Use this when the user signs out or you need to reset personalization.
 - Note: After logging out, you can call `.identify()` again to link a new or returning user.
 
**Example:**
```swift
do {
    try await Botsi.logout()
    // The SDK session is reverted to an anonymous state
} catch let error as BotsiError {
    print("Failed to logout user: \(error.localizedDescription)")
} catch {
    print("Unexpected error during user logout: \(error)")
}
```

## Profile Management

### `getProfile()`
```swift
static func getProfile() async throws -> BotsiProfile
```

Retrieves the current user's profile information.

**Returns:**
- `BotsiProfile`: The user's profile with information about their purchases and entitlements.

**Throws:**
- `BotsiError.userProfileNotFound`: If no profile has been created for the current user.

**Example:**
```swift
do {
    let profile = try await Botsi.getProfile()
    print("User profile ID: \(profile.profileId)")
    // Access other profile properties
} catch let error as BotsiError {
    print("Failed to get user profile: \(error)")
}
```

### `updateProfile(_:)`
```swift
static func updateProfile(_ profileUpdate: BotsiUserProfileInformation) async throws -> BotsiProfile
```

Updates the current user's profile with the provided information.

This method allows you to associate user profile information including birthday, email, username, gender, and phone. All fields are optional, and fields you leave out keep their current values. Custom attributes are added, or updated when their key already exists.

**Parameters:**
- `profileUpdate`: A `BotsiUserProfileInformation` object containing the fields to update.

**Returns:**
- `BotsiProfile`: Updated user profile after the update is complete.

**Throws:**
- `BotsiError.userProfileNotFound`: If no profile has been created for the current user.
- `BotsiError.customError`: With details if the network request fails.

**Example:**
```swift
do {
    let customEntries = [
        BotsiProfile.BotsiCustomEntry(key: "preference", value: "dark_mode", id: "1"),
        BotsiProfile.BotsiCustomEntry(key: "region", value: "US", id: "2")
    ]
    
    let profileUpdate = BotsiUserProfileInformation(
        birthday: Date(),
        email: "user@example.com",
        username: "john_doe",
        gender: .male,
        phone: "+1234567890",
        custom: customEntries
    )
    let updatedProfile = try await Botsi.updateProfile(profileUpdate)
    print("Profile updated successfully!")
} catch let error as BotsiError {
    print("Failed to update profile: \(error)")
}
```

**BotsiUserProfileInformation Structure:**
```swift
public struct BotsiUserProfileInformation {
    public let birthday: Date?
    public let email: String?
    public let username: String?
    public let gender: BotsiGender?
    public let phone: String?
    public let custom: [BotsiProfile.BotsiCustomEntry]?
    public let idfa: String?
    public let advertisingId: String?
}
```

**BotsiGender Options:**
```swift
public enum BotsiGender: String {
    case male = "male"
    case female = "female"
    case other = "other"
    case preferNotSay = "preferNotSay"
}
```

## Purchase Operations

### `makePurchase(_:)`
```swift
static func makePurchase(_ productId: String) async throws -> BotsiProfile
```

Initiates a purchase for the specified product ID.

**Parameters:**
- `productId`: The identifier of the product to purchase.

**Returns:**
- `BotsiProfile`: Updated user profile after the purchase is complete.

**Throws:**
- `BotsiError.transactionFailed`: If the purchase transaction fails.
- `BotsiError.customError`: With details if there are issues with StoreKit handlers.

**Example:**
```swift
do {
    let updatedProfile = try await Botsi.makePurchase("product_id")
    // Handle successful purchase
    print("Purchase successful! Updated profile: \(updatedProfile.profileId)")
} catch let error as BotsiError {
    print("Purchase failed: \(error)")
}
```

### `restorePurchases()`
```swift
static func restorePurchases() async throws -> BotsiProfile
```

Restores the user's App Store subscription onto the current profile. Call it from a Restore Purchases button: StoreKit syncs the user's transactions first and may ask them to sign in to the App Store.

The SDK also restores automatically, without any prompt, whenever it creates a profile. When there is nothing to restore, the profile is returned unchanged rather than as an error, so check its `accessLevels`.

**Returns:**
- `BotsiProfile`: Updated user profile with restored purchases.

**Throws:**
- `BotsiError.restoreFailed`: If the restore operation fails.

**Example:**
```swift
do {
    let restoredProfile = try await Botsi.restorePurchases()
    print("Purchases restored successfully!")
    // Check restored entitlements
} catch let error as BotsiError {
    print("Failed to restore purchases: \(error)")
}
```

## Paywall Management

### `getPaywall(from:)`
```swift
static func getPaywall(from placementId: String) async throws -> BotsiPaywall
```

Retrieves a paywall configuration for the specified placement ID.

**Parameters:**
- `placementId`: The identifier of the paywall placement.

**Returns:**
- `BotsiPaywall`: The paywall Botsi chose for the placement and its products.

**Throws:**
- `BotsiError.paywallFetchingFailed`: If no user profile exists.
- `BotsiError.sdkActivationKeyNotValid`: If the public key is wrong.
- `BotsiError.apiError`: With the status, code and message if Botsi rejects the request.

**BotsiPaywall Structure:**
```swift
public struct BotsiPaywall {
    public let placementId: String
    public let id: Int
    public let externalId: String?
    public let name: String
    public let isExperiment: Bool          // AI pricing chose this paywall as an experiment
    public let aiPricingModelId: Int?
    public let paywallSessionId: String    // links views and purchases to this display
    public let products: [BotsiPaywallProduct]
}

public struct BotsiPaywallProduct {
    public let paywallProductId: Int
    public let name: String
    public let period: String              // e.g. "monthly", "annual", "lifetime"
    public let appStore: BotsiAppStoreProduct?   // nil when not sold on the App Store
}

public struct BotsiAppStoreProduct {
    public let productId: String
    public let offerId: String?
    public let promotionalOfferId: String?
    public let offerType: String?          // e.g. "promotional", "win_back"
}
```

**Example:**
```swift
do {
    let paywall = try await Botsi.getPaywall(from: "paywall_name")
    // Configure your UI with the paywall information
    print("Paywall retrieved: \(paywall)")
} catch let error as BotsiError {
    print("Failed to get paywall: \(error)")
}
```

### `getPaywallProducts(from:)`
```swift
static func getPaywallProducts(from paywall: BotsiPaywall) async throws -> [BotsiProduct]
```

Retrieves detailed product information for all products in a paywall.

**Parameters:**
- `paywall`: A `BotsiPaywall` object obtained from `getPaywall(from:)`.

**Returns:**
- `[BotsiProduct]`: Array of product details including pricing, description, and other StoreKit information.

**Example:**
```swift
do {
    let paywall = try await Botsi.getPaywall(from: "paywall_name")
    let products = try await Botsi.getPaywallProducts(from: paywall)
    
    // Display products to the user
    for product in products {
        print("Product: \(product.title)")
        print("Price: \(product.price)")
        // Configure purchase buttons with product information
    }
} catch let error as BotsiError {
    print("Failed to get paywall products: \(error)")
}
```

### `logPaywallShown()`
```swift
    static func logPaywallShown(for paywall: BotsiPaywall) async throws
```

Reports that the user saw the paywall. Call it once per display, within about 24 hours of `getPaywall(from:)`; after that, fetch the paywall again.

**Example:**
```swift
do {
    let paywall = try await Botsi.getPaywall(from: "paywall_name")
    try await Botsi.logPaywallShown(for: paywall)
} catch let error as BotsiError {
    print("Failed to get paywall or send event: \(error)")
}
```

## Error Handling

The SDK uses `BotsiError` for error reporting. Common errors include:

- `BotsiError.userProfileNotFound`: No profile exists for the current user
- `BotsiError.transactionFailed`: Purchase transaction failed
- `BotsiError.restoreFailed`: Restore purchases operation failed
- `BotsiError.customError`: Custom errors with detailed information
- `BotsiError.paywallFetchingFailed`: Failed to fetch paywall information
- `BotsiError.sdkActivationKeyNotValid`: Incorrect public key provided
- `BotsiError.promoOfferNotConfigured`: The app's iOS settings in Botsi can't sign promotional offers, so the purchase didn't start
- `BotsiError.apiError(status:code:message:)`: Botsi rejected the request; `code` is a stable slug such as `not_found`
    

Properly handle these errors in your application to provide appropriate feedback to users.

## Objective-C Bridge

The Botsi SDK provides an Objective-C bridge (`BotsiObjCBridge.swift`) that enables seamless integration with Objective-C projects while maintaining full functionality of the Swift SDK.

### Core Components

**`BotsiObjCProfile` (Class)**
User profile with subscription and access information including `profileId`, `appUserId`, `accessLevels`, `subscriptions`, `nonSubscriptions`, and `custom` data.

**`BotsiObjCProduct` (Class)**
In-app purchase product representation with pricing, subscription details, and offer eligibility information.

**`BotsiObjCPaywall` (Class)**
The paywall Botsi chose for a placement: `placementId`, `paywallId`, `externalId`, `name`, `isExperiment`, `aiPricingModelId` and `paywallSessionId`.

**`BotsiObjCUserProfileInformation` (Class)**
Comprehensive user profile container including personal info, demographics, custom data, and device identifiers.

**`BotsiObjCError` (Class)**
Standardized error representation with `localizedDescription` and `errorCode`.

### Main SDK Interface

**`BotsiObjCSDK` (Class)**
Primary interface for all SDK operations. All methods are static and use completion handlers for asynchronous operations.

### API Methods

#### Initialization & Authentication
```objc
// Activate SDK with Public Key
+ (void)activate:(NSString *)key 
       completion:(void(^)(BotsiObjCError * _Nullable error))completion;

// Activate with Public Key and your user ID
+ (void)activate:(NSString *)key 
        appUserId:(NSString * _Nullable)appUserId 
       completion:(void(^)(BotsiObjCError * _Nullable error))completion;

// Identify user within your internal user management system
+ (void)identify:(NSString *)userId 
       completion:(void(^)(BotsiObjCError * _Nullable error))completion;

// Logout user
+ (void)logoutWithCompletion:(void(^)(BotsiObjCError * _Nullable error))completion;
```

#### Profile Management
```objc
// Retrieve user profile
+ (void)getProfileWithCompletion:(void(^)(BotsiObjCProfile * _Nullable profile, 
                                         BotsiObjCError * _Nullable error))completion;

// Update user profile
+ (void)updateProfile:(BotsiObjCUserProfileInformation *)profileUpdate 
           completion:(void(^)(BotsiObjCProfile * _Nullable profile, 
                              BotsiObjCError * _Nullable error))completion;
```

#### Paywall & Products
```objc
// Fetch paywall by placement ID
+ (void)getPaywallFrom:(NSString *)placementId 
             completion:(void(^)(BotsiObjCPaywall * _Nullable paywall, 
                                BotsiObjCError * _Nullable error))completion;

// Get products for specific paywall
+ (void)getPaywallProductsFrom:(BotsiObjCPaywall *)paywall 
                    completion:(void(^)(NSArray<BotsiObjCProduct *> * _Nullable products, 
                                       BotsiObjCError * _Nullable error))completion;
```

#### Purchases
```objc
// Make purchase
+ (void)makePurchase:(BotsiObjCProduct *)product 
           completion:(void(^)(BotsiObjCProfile * _Nullable profile, 
                              BotsiObjCError * _Nullable error))completion;

// Restore purchases
+ (void)restorePurchasesWithCompletion:(void(^)(BotsiObjCProfile * _Nullable profile, 
                                               BotsiObjCError * _Nullable error))completion;
```

#### Analytics & Consent
```objc
// Log paywall display
+ (void)logPaywallShown:(BotsiObjCPaywall *)paywall 
              completion:(void(^)(BotsiObjCError * _Nullable error))completion;

// Update refund consent
+ (void)updateRefundDataConsent:(BOOL)consent 
                     completion:(void(^)(BotsiObjCError * _Nullable error))completion;
```

### Example Usage

```objc 
// Example method that incorporates main SDK methods
- (void)activateAndFetchProducts {
    // activate SDK with your public key
    [BotsiObjCSDK activate:@"pk_VgKsJTMAUVJOHopK.llSPKivjLLlsgpPAb123OWzYbo9o" completion:^(BotsiObjCError *error) {
        if (error) { NSLog(@"Activation failed: %@", error.localizedDescription); return; }
        [self fetchAndDisplayProfile]; // update UI
        // fetch Paywall by the placement ID key
        [BotsiObjCSDK getPaywallFrom:@"your_placement_id" completion:^(BotsiObjCPaywall *paywall, BotsiObjCError *error) {
            if (error) { NSLog(@"Failed to get paywall: %@", error.localizedDescription); return; }
            NSLog(@"Successfully got paywall: %@", paywall);
            // retrieve products from paywall
            [BotsiObjCSDK getPaywallProductsFrom:paywall completion:^(NSArray<BotsiObjCProduct *> *products, BotsiObjCError *error) {
                if (error) { NSLog(@"Failed to retrieve products: %@", error.localizedDescription); return; }
                // update UI
                self.products = products;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadData];
                });
                NSLog(@"About to call logPaywallShown with paywall: %@", paywall);
                // send analytics event to console
                [BotsiObjCSDK logPaywallShown:paywall completion:^(BotsiObjCError *error) {
                    NSLog(@"logPaywallShown completion called");
                    if (error) { 
                        NSLog(@"Failed to log paywall shown: %@", error.localizedDescription); 
                    } else {
                        NSLog(@"Successfully logged paywall shown");
                    }
                }];
            }];
        }];
    }];
}
```
