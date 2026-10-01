//
//  Botsi.swift
//  Botsi
//
//  Created by Vladyslav on 19.02.2025.
//

import Foundation

@BotsiActor
public final class Botsi: Sendable {
    let sdkApiKey: String
        
    let profileStorage: BotsiProfileStorage
    static let lifecycle = BotsiLifecycle()

    private let storeKit2Handler: StoreKit2Handler

    private let configuration: BotsiConfiguration
    
    let botsiClient: BotsiHttpClient
    let profilesRepository: BotsiProfilesRepository
    private let paywallsRepository: BotsiPaywallsRepository
    
    init(from configuration: BotsiConfiguration) async {
        self.sdkApiKey = configuration.sdkApiKey
        self.configuration = configuration
        
        self.botsiClient = BotsiHttpClient(with: configuration)
        self.profilesRepository = BotsiProfilesRepository(httpClient: botsiClient)
        self.paywallsRepository = BotsiPaywallsRepository(httpClient: botsiClient)
        self.profileStorage = await BotsiProfileStorage()

        self.storeKit2Handler = StoreKit2Handler(
            client: botsiClient,
            storage: profileStorage
        )

        await verifyUser()
        await storeKit2Handler.startObservingTransactions()
        
        Task.detached {
            let ip = try await IPAddressManager.getIPAddress()
            let profileInfo = BotsiUserProfileInformation(ipAddress: ip)
            try await self.updateUserProfile(profileUpdate: profileInfo)
        }
    }
    
    private func verifyUser() async {
        guard let profile = await profileStorage.getProfile() else {
            await createProfileSafely(appUserId: configuration.appUserId)
            return
        }
        
        // Without an appUserId, keep whoever is signed in; `logout()` is how a user leaves.
        if let appUserId = configuration.appUserId, appUserId != profile.appUserId {
            BotsiLog.info("appUserId changed from '\(profile.appUserId ?? "nil")' to '\(appUserId)'. Switching to new user profile.")
            await clearIfAnotherUser(profile)
            await createProfileSafely(appUserId: appUserId)
            return
        }
        
        await updateExistingProfile(profile)
    }
    
    /// An anonymous profile stays current if switching to a signed-in user fails, since it's the same
    /// person. Another user's profile doesn't, so their purchases can't be credited to the wrong user.
    private func clearIfAnotherUser(_ profile: BotsiProfile) async {
        if profile.appUserId != nil {
            await profileStorage.clearProfile()
        }
    }
    
    private func createProfileSafely(appUserId: String?) async {
        do {
            try await createAndSetupNewProfile(appUserId: appUserId)
        } catch {
            BotsiLog.error("Unable to create profile: \(error.localizedDescription)")
        }
    }
    
    /// Creates a profile, or finds the existing one when Botsi already knows `appUserId`, and makes it the
    /// current profile. Then sends the Apple Search Ads token and restores any App Store subscription onto it.
    ///
    /// If Botsi can't be reached, the previous profile stays current; callers clear it first when it must not.
    @discardableResult
    private func createAndSetupNewProfile(appUserId: String?) async throws -> BotsiProfile {
        let environment = await BotsiEnvironment.current()
        let profileId = try await profilesRepository.createProfile(appUserId: appUserId, environment: environment)
        // Creation leaves an existing profile's details unchanged, so they're sent separately.
        let profile = appUserId == nil
            ? try await profilesRepository.getProfile(profileId: profileId)
            : try await profilesRepository.updateProfile(profileId: profileId, update: BotsiUpdateProfileRequestDto(environment))
        await profileStorage.clearProfile()
        await profileStorage.setProfile(profile)
        await profileStorage.setSavedEnvironment(environment)
        await updateASAToken(profile.profileId)
        await restorePurchasesSafely()
        return await profileStorage.getProfile() ?? profile
    }
    
    /// Refreshes the saved profile, and sends the device and app details again if they changed since last time.
    private func updateExistingProfile(_ profile: BotsiProfile) async {
        do {
            let environment = await BotsiEnvironment.current()
            let updatedProfile: BotsiProfile
            if await profileStorage.savedEnvironment() != environment {
                updatedProfile = try await profilesRepository.updateProfile(
                    profileId: profile.profileId,
                    update: BotsiUpdateProfileRequestDto(environment)
                )
                await profileStorage.setSavedEnvironment(environment)
            } else {
                updatedProfile = try await profilesRepository.getProfile(profileId: profile.profileId)
            }
            BotsiLog.info("Fetched updated user profile with id: \(updatedProfile.profileId)")
            await profileStorage.setProfile(updatedProfile)
        } catch {
            BotsiLog.error("Unable to update profile: \(error.localizedDescription)")
        }
    }
    
    private func restorePurchasesSafely() async {
        do {
            try await restorePurchases(syncWithAppStore: false)
        } catch {
            BotsiLog.error("Unable to restore purchases: \(error.localizedDescription)")
        }
    }
    
    func requireProfileId() async throws -> String {
        guard let profileId = await profileStorage.currentProfileId() else {
            throw BotsiError.userProfileNotFound
        }
        return profileId
    }
}

public extension Botsi {
    /// Activates and initializes the Botsi SDK with your configuration.
    ///
    /// This is the entry point for using the Botsi SDK. Call this method before using any other
    /// SDK functionality. The SDK will create and manage user profiles automatically.
    ///
    /// - Parameter key: Your app's public SDK key from the Botsi dashboard.
    /// - Parameter appUserId: Your own ID for the user, such as `user_1234`. Leave it out for an anonymous user.
    ///
    /// - Throws: An error if the SDK fails to initialize properly.
    ///
    /// - Example:
    ///   ```swift
    ///   do {
    ///       try await Botsi.activate("your_public_sdk_key", appUserId: "user_12345")
    ///       // SDK is now initialized and ready for use
    ///   } catch {
    ///       print("Failed to initialize Botsi SDK: \(error)")
    ///   }
    ///   ```
    
    nonisolated static func activate(_ key: String, appUserId: String? = nil) async throws {
        let configuration = BotsiConfiguration.build(sdkApiKey: key)
            .set(appUserId: appUserId)
        try await proceedWithActivation(with: configuration)
    }
    
    nonisolated static func activate(_ configuration: BotsiConfiguration) async throws {
        try await proceedWithActivation(with: configuration)
    }
    
    private static func proceedWithActivation(with configuration: BotsiConfiguration) async throws {
        try await lifecycle.initializeIfNeeded {
            let botsi = await Botsi(from: configuration)
            return botsi
        }
    }
    
    /// Links the SDK session to a specific user in your own system.
    ///
    /// If you didn’t provide a user ID when initializing the SDK, you can call `.identify()` at any point—most often right after the user signs up or logs in, moving from an anonymous session to an authenticated one.
    ///
    /// Botsi finds the user's existing profile when it already knows `userId`, and then restores the user's App Store subscription onto it.
    ///
    /// - Parameter userId: The unique identifier for the user in your system.
    
    nonisolated static func identify(_ userId: String) async throws {
        try await lifecycle.withInitializedSDK { botsi in
            try await botsi.identifyUser(with: userId)
        }
    }
    
    private func identifyUser(with appUserId: String) async throws {
        if let profile = await profileStorage.getProfile() {
            guard profile.appUserId != appUserId else { return }
            BotsiLog.info("appUserId changed from '\(profile.appUserId ?? "nil")' to '\(appUserId)'. Switching to new user profile.")
            await clearIfAnotherUser(profile)
        }
        try await createAndSetupNewProfile(appUserId: appUserId)
    }
    
    /// Ends the current user session and reverts the SDK to an anonymous state.
    ///
    /// Calling `.logout()` removes any stored user identifier and clears session-specific data, so subsequent calls behave as if no user is signed in. Use this when the user signs out or you need to reset personalization.
    ///
    /// - Note: After logging out, you can call `.identify()` again to link a new or returning user.
    
    nonisolated static func logout() async throws {
        try await lifecycle.withInitializedSDK { botsi in
            try await botsi.clearProfile()
        }
    }
    
    private func clearProfile() async throws {
        // Signed-out data goes even if Botsi can't be reached to create the anonymous profile.
        await profileStorage.clearProfile()
        try await createAndSetupNewProfile(appUserId: nil)
    }
    
    /// Checks if the Botsi SDK has been properly initialized.
    ///
    /// Use this property to verify that the SDK has been successfully initialized
    /// before attempting to use any of its functionality.
    ///
    /// - Returns: `true` if the SDK has been initialized, `false` otherwise.
    
    static var isInitialized: Bool {
        get async {
            await lifecycle.isInitialized
        }
    }
    
    /// Retrieves the current user's profile information.
    ///
    /// This method returns the user profile with information about their purchases and entitlements.
    /// A user profile is automatically created during SDK initialization.
    ///
    /// - Returns: The user's `BotsiProfile` with complete information about purchases and entitlements.
    ///
    /// - Throws: `BotsiError.userProfileNotFound` if no profile has been created for the current user,
    ///           or other errors if the network request fails.
    ///
    /// - Example:
    ///   ```swift
    ///   do {
    ///       let profile = try await Botsi.getProfile()
    ///       print("User profile ID: \(profile.profileId)")
    ///       // Access other profile properties
    ///   } catch {
    ///       print("Failed to get user profile: \(error)")
    ///   }
    ///   ```
    nonisolated static func getProfile() async throws -> BotsiProfile {
        return try await lifecycle.withInitializedSDK { botsi in
            try await botsi.getUserProfile()
        }
    }
    
    /// Updates the current user's profile with the provided information.
    ///
    /// This method allows to associate user profile information including birthday, email,
    /// username, gender, phone, and IP address. All fields are optional.
    ///
    /// - Parameter profileUpdate: A `BotsiUserProfileInformation` object containing the fields to update.
    ///
    /// - Returns: Updated user profile after the update is complete.
    ///
    /// - Throws: `BotsiError.userProfileNotFound` if no profile has been created for the current user,
    ///           or other errors if the network request fails.
    ///
    /// - Example:
    ///   ```swift
    ///   do {
    ///       let customEntries = [
    ///           BotsiProfile.BotsiCustomEntry(key: "preference", value: "dark_mode", id: "1"),
    ///           BotsiProfile.BotsiCustomEntry(key: "region", value: "US", id: "2")
    ///       ]
    ///       
    ///       let profileUpdate = BotsiUserProfileInformation(
    ///           birthday: Date(),
    ///           email: "user@example.com",
    ///           username: "john_doe",
    ///           gender: .male,
    ///           phone: "+1234567890",
    ///           custom: customEntries
    ///       )
    ///       let updatedProfile = try await Botsi.updateProfile(profileUpdate)
    ///       print("Profile updated successfully!")
    ///   } catch {
    ///       print("Failed to update profile: \(error)")
    ///   }
    ///   ```
    nonisolated static func updateProfile(_ profileUpdate: BotsiUserProfileInformation) async throws -> BotsiProfile {
        return try await lifecycle.withInitializedSDK { botsi in
            try await botsi.updateUserProfile(profileUpdate: profileUpdate)
        }
    }
    
    /// Saves custom attributes first, then the other fields, and returns the profile with both.
    @discardableResult
    private func updateUserProfile(profileUpdate: BotsiUserProfileInformation) async throws -> BotsiProfile {
        let profileId = try await requireProfileId()
        if let custom = profileUpdate.custom, !custom.isEmpty {
            try await profilesRepository.setCustomAttributes(profileId: profileId, entries: custom)
        }
        let profile = try await profilesRepository.updateProfile(
            profileId: profileId,
            update: BotsiUpdateProfileRequestDto(profileUpdate)
        )
        await profileStorage.setProfile(profile)
        return profile
    }
    
    @discardableResult
    private func getUserProfile() async throws -> BotsiProfile {
        let profile = try await profilesRepository.getProfile(profileId: try await requireProfileId())
        await profileStorage.setProfile(profile)
        return profile
    }

    /// Initiates a purchase for the specified product ID.
    ///
    /// This method handles the entire purchase flow, including presenting the system purchase dialog,
    /// validating the purchase with Apple, and updating the user's profile with the new entitlements.
    ///
    /// - Parameter productId: The identifier of the product to purchase.
    ///
    /// - Returns: Updated user profile after the purchase is complete.
    ///
    /// - Throws: `BotsiError.transactionFailed` if the purchase transaction fails,
    ///           `BotsiError.customError` with details if there are issues with StoreKit handlers,
    ///           or other errors if the product does not exist.
    ///
    /// - Example:
    ///   ```swift
    ///   do {
    ///       let updatedProfile = try await Botsi.makePurchase("premium_subscription")
    ///       // Handle successful purchase
    ///       print("Purchase successful! Updated profile: \(updatedProfile.profileId)")
    ///   } catch {
    ///       print("Purchase failed: \(error)")
    ///   }
    ///   ```
    nonisolated static func makePurchase(_ product: BotsiProduct) async throws -> BotsiProfile {
        return try await lifecycle.withInitializedSDK { botsi in
            try await botsi.makePurchase(from: product)
        }
    }
    
    func makePurchase(from product: BotsiProduct) async throws -> BotsiProfile {
        do {
            let profile = try await storeKit2Handler.purchaseSK2(product)
            return profile
        } catch let error as BotsiError {
            BotsiLog.error("Failed to purchase: \(error.localizedDescription)")
            throw error
        } catch {
            BotsiLog.error("Failed to purchase: \(error.localizedDescription)")
            throw BotsiError.transactionFailed
        }
    }
    
    /// Restores previously purchased products for the current user.
    ///
    /// Call this from a Restore Purchases button. StoreKit syncs the user's transactions first and may
    /// ask them to sign in to the App Store. Botsi then restores the newest App Store subscription the
    /// user is entitled to onto the current profile.
    ///
    /// The SDK already restores automatically, without any prompt, whenever it creates a profile.
    ///
    /// - Returns: The updated profile. Check its `accessLevels`: when there was nothing to restore,
    ///   the profile comes back unchanged rather than as an error.
    ///
    /// - Throws: `BotsiError.apiError` if Botsi rejects the request,
    ///           or other errors if the network request fails.
    ///
    /// - Example:
    ///   ```swift
    ///   do {
    ///       let restoredProfile = try await Botsi.restorePurchases()
    ///       print("Purchases restored successfully!")
    ///       // Check restored entitlements
    ///   } catch {
    ///       print("Failed to restore purchases: \(error)")
    ///   }
    ///   ```
    nonisolated static func restorePurchases() async throws -> BotsiProfile {
        try await lifecycle.withInitializedSDK { botsi in
            return try await botsi.restorePurchases(syncWithAppStore: true)
        }
    }
    
    /// - Parameter syncWithAppStore: `true` only when the user asked to restore; StoreKit may ask them to sign in.
    @discardableResult
    private func restorePurchases(syncWithAppStore: Bool) async throws -> BotsiProfile {
        do {
            let userProfile = try await storeKit2Handler.restorePurchases(syncWithAppStore: syncWithAppStore)
            return userProfile
        } catch let error as BotsiError {
            throw error
        } catch {
            BotsiLog.error("Failed to restore: \(error.localizedDescription)")
            throw BotsiError.restoreFailed
        }
    }
}

public extension Botsi {
    // MARK: - Paywall Management

    /// Retrieves a paywall configuration for the specified placement ID.
    ///
    /// Botsi chooses the paywall for the placement, including through AI pricing, and returns it with
    /// its products. Pass it to `getPaywallProducts(from:)` for StoreKit prices, and to
    /// `logPaywallShown(for:)` once the user sees it.
    ///
    /// - Parameter placementId: The identifier of the paywall placement.
    ///
    /// - Returns: The paywall, its products and the `paywallSessionId` that links views and purchases to it.
    ///
    /// - Throws: `BotsiError.paywallFetchingFailed` if no user profile exists,
    ///           `BotsiError.apiError` if Botsi rejects the request, or other errors if the network request fails.
    ///
    nonisolated static func getPaywall(from placementId: String) async throws -> BotsiPaywall {
        try await lifecycle.withInitializedSDK { botsi in
            return try await botsi.getPaywall(from: placementId)
        }
    }
    
    private func getPaywall(from placementId: String) async throws -> BotsiPaywall {
        guard let profileId = await profileStorage.currentProfileId() else {
            throw BotsiError.paywallFetchingFailed
        }
        return try await paywallsRepository.getPaywall(profileId: profileId, placementId: placementId)
    }

    /// Retrieves detailed product information for all products in a paywall.
    ///
    /// This method takes a paywall configuration and fetches detailed information for all products
    /// referenced in that paywall, including pricing, descriptions, and other StoreKit information.
    ///
    /// - Parameter paywall: A `BotsiPaywall` object obtained from `getPaywall(from:)`.
    ///
    /// - Returns: Array of product details including pricing, description, and other StoreKit information.
    ///
    /// - Throws: An error if product details cannot be retrieved or if the SDK is not initialized.
    ///
    /// - Example:
    ///   ```swift
    ///   do {
    ///       let paywall = try await Botsi.getPaywall(from: "main_screen_premium")
    ///       let products = try await Botsi.getPaywallProducts(from: paywall)
    ///
    ///       // Display products to the user
    ///       for product in products {
    ///           print("Product: \(product.title)")
    ///           print("Price: \(product.price)")
    ///           // Configure purchase buttons with product information
    ///       }
    ///   } catch {
    ///       print("Failed to get paywall products: \(error)")
    ///   }
    ///   ```
    nonisolated static func getPaywallProducts(from paywall: BotsiPaywall) async throws -> [BotsiProduct] {
        try await lifecycle.withInitializedSDK { botsi in
            return try await botsi.retrieveProductDetails(from: paywall)
        }
    }
    
    private func retrieveProductDetails(from paywall: BotsiPaywall) async throws -> [BotsiProduct] {
        let products: [BotsiProduct] = try await getBotsiProducts(paywall: paywall, handler: storeKit2Handler)
        return products
    }
    
    // MARK: - Events
    private func logPaywallShown(_ paywall: BotsiPaywall) async throws {
        try await paywallsRepository.logPaywallShown(paywallSessionId: paywall.paywallSessionId)
    }
    
    /// Reports that the user saw the paywall. Call it once per display, within about 24 hours of
    /// fetching the paywall; after that, fetch it again.
    nonisolated static func logPaywallShown(for paywall: BotsiPaywall) async throws {
        try await lifecycle.withInitializedSDK { botsi in
            try await botsi.logPaywallShown(paywall)
        }
    }
    
    nonisolated static func updateRefundDataConsent(_ consent: Bool) async throws {
        try await lifecycle.withInitializedSDK { botsi in
            return try await botsi.sendRefundDataConsent(consent)
        }
    }
    
    private func sendRefundDataConsent(_ consent: Bool) async throws {
        try await profilesRepository.setAppleConsumptionConsent(profileId: try await requireProfileId(), consent: consent)
    }
}
