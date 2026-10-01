# Botsi iOS SDK Documentation

The Botsi SDK enables seamless in-app purchases and paywall management in iOS applications. This documentation covers the public API methods available for integration.

## Table of Contents
- [Installation](#installation)
- [Initialization](#initialization)
- [Profile Management](#profile-management)
- [Product Management](#product-management)
- [Purchase Operations](#purchase-operations)
- [Paywall Management](#paywall-management)
- [Objective-C Bridge](#objective-c-bridge)

## Installation

To integrate the BotsiSDK into your project using Swift Package Manager (SPM), follow these steps:

1. **Open Your Project in Xcode**  
   Launch your iOS project in Xcode.

2. **Add the Package Dependency**  
   From the menu, navigate to **File** > **Swift Packages** > **Add Package Dependency...**.

3. **Enter the Repository URL**  
   When prompted, enter the repository URL below:

https://github.com/BotsiTeam/BotsiSDK-iOS.git

4. **Specify the Version**  
Under the version rule options, select **Version** and specify the SDK version:

Latest version is: 1.0.12

5. **Finalize Installation**  
Xcode will download and integrate the SDK into your project. Once added, you can start using the SDK immediately.

6. **Import the SDK in Your Code**  
In your source files, add the following import statement:

```swift
import Botsi
```

CocoaPods

To integrate the BotsiSDK into your project using CocoaPods, follow these steps:

1. **Add the SDK to your Podfile and add the following line:**
pod 'BotsiSDK', '~> 1.0.12'

2. **Install the PodRun the following command to install the SDK:**
pod install

3. **Open the generated .xcworkspace file in Xcode instead of the .xcodeproj.**

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

### `activate(_ key:customerUserId:)`
```swift
static func activate(_ key: String, customerUserId: String?) async throws
```

Activates and initializes the Botsi SDK with your public key and optionally links it to a specific user in your system.

**Parameters:**
- `key`: Your Botsi SDK API key
- `customerUserId`: Optional identifier for the user in your system. If provided, the SDK profile will be linked to this user immediately upon activation.

**Example:**
```swift
do {
    // Activate with user ID for immediate user linking
    try await Botsi.activate("your_api_key", customerUserId: "user_12345")
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

This method allows you to associate user profile information including birthday, email, username, gender, and phone. All fields are optional.

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
    public let ip: String?
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

Restores previously purchased products for the current user.

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
- `BotsiPaywall`: The paywall configuration with UI elements and product references.

**Throws:**
- `BotsiError.userProfileNotFound`: If no user profile exists.
- `BotsiError.sdkActivationKeyNotValid`: If user entered wrong public key.
- `BotsiError.customError`: With details if there are issues with fetching profile.

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

Sends an event to collect analytics. Should be called together with getPaywall(from:)

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
    

Properly handle these errors in your application to provide appropriate feedback to users.

## Objective-C Bridge

The Botsi SDK provides an Objective-C bridge (`BotsiObjCBridge.swift`) that enables seamless integration with Objective-C projects while maintaining full functionality of the Swift SDK.

### Core Components

**`BotsiObjCProfile` (Class)**
User profile with subscription and access information including `profileId`, `customerUserId`, `accessLevels`, `subscriptions`, `nonSubscriptions`, and `custom` data.

**`BotsiObjCProduct` (Class)**
In-app purchase product representation with pricing, subscription details, and offer eligibility information.

**`BotsiObjCPaywall` (Class)**
Paywall configuration and metadata including placement ID, paywall ID, name, and configuration details.

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

// Activate with Public Key and Customer user ID
+ (void)activate:(NSString *)key 
   customerUserId:(NSString * _Nullable)customerUserId 
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
