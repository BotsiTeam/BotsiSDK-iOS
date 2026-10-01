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
    fileprivate let cachedTransactionsStore: BotsiSyncedTransactionStore
    static let lifecycle = BotsiLifecycle()
    
    private let storeKit1Handler: StoreKit1Handler?
    private let storeKit2Handler: StoreKit2Handler?
    
    private let enableStoreKit2: Bool = true
    
    private let configuration: BotsiConfiguration
    
    let botsiClient: BotsiHttpClient
    
    init(from configuration: BotsiConfiguration) async {
        self.sdkApiKey = configuration.sdkApiKey
        self.configuration = configuration
        
        self.botsiClient = BotsiHttpClient(with: configuration)
        self.profileStorage = await BotsiProfileStorage()
        
        let cachedTransactionsStore = await BotsiSyncedTransactionStore()
        self.cachedTransactionsStore = cachedTransactionsStore
        
        if #available(iOS 15.0, *), enableStoreKit2 {
            self.storeKit2Handler = StoreKit2Handler(
                client: botsiClient,
                storage: profileStorage
            )
            self.storeKit1Handler = nil
        } else {
            let storeKit1Handler = StoreKit1Handler(
                client: botsiClient,
                storage: profileStorage,
                configuration: configuration,
                cachedTransactionsStore: self.cachedTransactionsStore
            )
            self.storeKit1Handler = storeKit1Handler
            await self.storeKit1Handler?.startObservingTransactions()
            self.storeKit2Handler = nil
        }
        
        await verifyUser()
        
        Task.detached {
            let ip = try await IPAddressManager.getIPAddress()
            let profileInfo = BotsiUserProfileInformation(ip: ip)
            try await self.updateUserProfile(profileUpdate: profileInfo)
        }
    }
    
    private func verifyUser() async {
        guard let profile = await profileStorage.getProfile() else {
            await createAndSetupNewProfile()
            return
        }
        
        if profile.customerUserId != configuration.customerUserId {
            await switchToNewUserProfile()
            return
        }
        
        await updateExistingProfile(profile)
    }
    
    private func createAndSetupNewProfile() async {
        let uuid = await profileStorage.getNewProfileUUID()
        if let profile = try? await createUserProfile(with: uuid, userCustomerId: configuration.customerUserId) {
            await profileStorage.setProfile(profile)
            await updateASAToken(profile.profileId)
            await restorePurchasesSafely()
        }
    }
    
    private func switchToNewUserProfile() async {
        guard let currentProfile = await profileStorage.getProfile() else { return }
        
        BotsiLog.info("CustomerUserId changed from '\(currentProfile.customerUserId ?? "nil")' to '\(configuration.customerUserId ?? "nil")'. Switching to new user profile.")
        
        let newUuid = await profileStorage.getNewProfileUUID()
        await profileStorage.clearProfile()
        
        if let newProfile = try? await createUserProfile(with: newUuid, userCustomerId: configuration.customerUserId) {
            await profileStorage.setProfile(newProfile)
            await updateASAToken(newProfile.profileId)
            await restorePurchasesSafely()
        }
    }
    
    private func updateExistingProfile(_ profile: BotsiProfile) async {
        do {
            let updatedProfile = try await getUserProfile()
            BotsiLog.info("Fetched updated user profile with id: \(updatedProfile.profileId)")
            await profileStorage.setProfile(updatedProfile)
        } catch {
            BotsiLog.error("Unable to update profile: \(error.localizedDescription)")
        }
    }
    
    private func restorePurchasesSafely() async {
        do {
            try await restorePurchases()
        } catch {
            BotsiLog.error("Unable to restore purchases: \(error.localizedDescription)")
        }
    }
}

public extension Botsi {
    /// Activates and initializes the Botsi SDK with your configuration.
    ///
    /// This is the entry point for using the Botsi SDK. Call this method before using any other
    /// SDK functionality. The SDK will create and manage user profiles automatically.
    ///
    /// - Parameter key: A string object containing your SDK API key.
    /// - Parameter customerUserId: A string object containing an internal user identifier, e.g. `john@doe.com` or `user_1234`.
    ///
    /// - Throws: An error if the SDK fails to initialize properly.
    ///
    /// - Example:
    ///   ```swift
    ///   do {
    ///       try await Botsi.activate("your_api_key", customerUserId: "user_12345")
    ///       // SDK is now initialized and ready for use
    ///   } catch {
    ///       print("Failed to initialize Botsi SDK: \(error)")
    ///   }
    ///   ```
    
    nonisolated static func activate(_ key: String, customerUserId: String? = nil) async throws {
        let configuration = BotsiConfiguration.build(sdkApiKey: key)
            .set(customerUserIdentifier: customerUserId)
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
    
    static func withInitializedSDK<T: Sendable>(
        identifier: BotsiRequestIdentifier,
        caller: StaticString = #function,
        operation: @BotsiActor @Sendable @escaping (Botsi) async throws -> T
    ) async throws -> T {
        try await lifecycle.withInitializedSDK(operation: operation)
    }
    
    /// /// Links the SDK session to a specific user in your own system.
    ///
    /// If you didn’t provide a user ID when initializing the SDK, you can call `.identify()` at any point—most often right after the user signs up or logs in, moving from an anonymous session to an authenticated one.
    ///
    /// - Parameter userId: The unique identifier for the user in your system.
    
    nonisolated static func identify(_ userId: String) async throws {
        try await lifecycle.withInitializedSDK { botsi in
            try await botsi.identifyUser(with: userId)
        }
    }
    
    private func identifyUser(with customerUserId: String) async throws {
        guard let profile = await profileStorage.getProfile() else {
            let uuid = await profileStorage.getNewProfileUUID()
            if let profile = try? await createUserProfile(with: uuid, userCustomerId: customerUserId) {
                await profileStorage.setProfile(profile)
                await restorePurchasesSafely()
            }
            return
        }
        
        guard profile.customerUserId != customerUserId else { return }
        
        BotsiLog.info("CustomerUserId changed from '\(profile.customerUserId ?? "nil")' to '\(customerUserId)'. Switching to new user profile.")
        
        let newUuid = await profileStorage.getNewProfileUUID()
        await profileStorage.clearProfile()
        
        if let newProfile = try? await createUserProfile(with: newUuid, userCustomerId: customerUserId) {
            await profileStorage.setProfile(newProfile)
            await restorePurchasesSafely()
        }
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
        await profileStorage.clearProfile()
        await createAndSetupNewProfile()
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
    typealias ProfileIdentifier = String
    typealias UserCustomerIdentifier = String
    
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
    
    @discardableResult
    private func createUserProfile(
        with id: ProfileIdentifier,
        userCustomerId: UserCustomerIdentifier? = nil
    ) async throws -> BotsiProfile {
        let createProfile = UserProfileRepository(httpClient: botsiClient)
        return try await createProfile.createUserProfile(
            identifier: id,
            customerId: userCustomerId
        )
    }
    
    @discardableResult
    private func updateUserProfile(profileUpdate: BotsiUserProfileInformation) async throws -> BotsiProfile {
        let userId = await profileStorage.currentProfileId()
        let updateUserRepository = UpdateUserProfileRepository(httpClient: botsiClient)
        let useCase = BotsiUpdateProfileUseCase(repository: updateUserRepository)
        let profile = try await useCase.execute(identifier: userId, profileUpdate: profileUpdate)
        await profileStorage.setProfile(profile)
        return profile
    }
    
    @discardableResult
    private func getUserProfile() async throws -> BotsiProfile {
        if let storedProfile = await profileStorage.getProfile() {
            let repository = GetUserProfileRepository(httpClient: botsiClient)
            return try await repository.getUserProfile(identifier: storedProfile.profileId)
        } else {
            throw BotsiError.userProfileNotFound
        }
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
            if #available(iOS 15.0, *), enableStoreKit2 {
                guard let handler = storeKit2Handler else {
                    throw BotsiError.customError("SK2PurchaseError", "unable to unwrap Storekit 2 handler")
                }
                let profile = try await handler.purchaseSK2(product)
                return profile
            } else {
                guard let handler = storeKit1Handler else {
                    throw BotsiError.customError("SK1PurchaseError", "unable to unwrap Storekit 1 handler")
                }
                let profile = try await handler.purchaseSK1(product)
                return profile
            }
        } catch let error as BotsiError {
            BotsiLog.error("Failed to purchase: \(error.localizedDescription)")
            throw error
        } catch let error as SK1Error {
            BotsiLog.error("SKError failed to purchase: \(error.errorCode) \(error.errorUserInfo) \(error.localizedDescription)")
            throw BotsiError.transactionFailed
        } catch {
            BotsiLog.error("Failed to purchase: \(error.localizedDescription)")
            throw BotsiError.transactionFailed
        }
    }
    
    /// Restores previously purchased products for the current user.
    ///
    /// Use this method to allow users to restore their previous purchases, typically when they
    /// install your app on a new device or after reinstalling the app. This method will update
    /// the user's profile with all previously purchased entitlements.
    ///
    /// - Returns: Updated user profile with restored purchases.
    ///
    /// - Throws: `BotsiError.restoreFailed` if the restore operation fails,
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
            return try await botsi.restorePurchases()
        }
    }
    
    @discardableResult
    private func restorePurchases() async throws -> BotsiProfile {
        do {
            if #available(iOS 15.0, *), enableStoreKit2 {
                guard let handler = storeKit2Handler else {
                    throw BotsiError.customError("restoreError", "unable to unwrap storekit 2 handler")
                }
                let userProfile = try await handler.restorePurchases()
                return userProfile
            } else {
                guard let handler = storeKit1Handler else {
                    throw BotsiError.customError("restoreError", "unable to unwrap storekit 1 handler")
                }
                let userProfile = try await handler.restorePurchases()
                return userProfile
            }
        } catch {
            throw BotsiError.restoreFailed
        }
    }
}

public extension Botsi {
    // MARK: - Paywall Management

    /// Retrieves a paywall configuration for the specified placement ID.
    ///
    /// Paywalls contain UI elements and product references for displaying purchase options to users.
    /// Each paywall is configured in the Botsi dashboard and can be retrieved by its placement ID.
    ///
    /// - Parameter placementId: The identifier of the paywall placement.
    ///
    /// - Returns: The paywall configuration with UI elements and product references.
    ///
    /// - Throws: `BotsiError.userProfileNotFound` if no user profile exists,
    ///           or other errors if the network request fails.
    ///
    nonisolated static func getPaywall(from placementId: String) async throws -> BotsiPaywall {
        try await lifecycle.withInitializedSDK { botsi in
            return try await botsi.getPaywall(from: placementId)
        }
    }
    
    private func getPaywall(from id: String) async throws -> BotsiPaywall {
        guard let profile = await profileStorage.getProfile() else {
            throw BotsiError.paywallFetchingFailed
        }
        let repository = GetPaywallRepository(httpClient: botsiClient, profileId: profile.profileId)
        return try await repository.getPaywall(id: id)
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
        if #available(iOS 15.0, *), enableStoreKit2 {
            guard let handler = storeKit2Handler else {
                throw BotsiError.customError("retrieveProductDetailsError", "unable to unwrap storekit 2 handler")
            }
            let products: [BotsiProduct] = try await getBotsiProducts(paywall: paywall, handler: handler)
            return products
        } else {
            guard let handler = storeKit1Handler,
                    let profile = await profileStorage.getProfile()
            else {
                throw BotsiError.customError("retrieveProductDetailsError", "unable to unwrap storekit 1 handler")
            }
            let products: [BotsiProduct] = try await getBotsiProductsForSK1(
                profileId: profile.profileId,
                paywall: paywall,
                handler: handler
            )
            return products
        }
    }
    
    // MARK: - Events
    /// `Analytics`
    nonisolated private func sendPaywallTrackEvent(event: BotsiLogEvent) async throws {
        let eventsRepository = EventsRepository(httpClient: botsiClient)
        let useCase = BotsiSendEventUseCase(repository: eventsRepository)
        try await useCase.execute(
            profileId: event.profileId,
            paywallId: event.paywallId,
            abTestId: event.abTestId,
            eventType: event.type.rawValue,
            placementId: event.placementId,
            aiPricingModelId: event.aiPricingModelId,
            isExperiment: event.isExperiment
        )
    }
    
    private func logPaywallShown(_ paywall: BotsiPaywall) async throws {
        let profileId = await profileStorage.currentProfileId()
        let environment = try await BotsiEnvironment()
        let customContext = BotsiLogEventContext(
            userId: profileId,
            environment: environment
        )
        let loggerWithContext = BotsiEventLoggerFactory.createLoggerWithContext(
            initialContext: customContext,
            sendEventFunction: { @Sendable [unowned self] event in
                try await self.sendPaywallTrackEvent(event: event)
            }
        )

        let userActionEvent = BotsiLogEvent(
            profileId: profileId,
            paywallId: paywall.id,
            abTestId: paywall.abTestId,
            type: .userPaywallShown,
            name: "userPaywallPresentedLog",
            message: "Paywall presented.",
            placementId: paywall.placementId,
            aiPricingModelId: paywall.aiPricingModelId,
            isExperiment: paywall.isExperiment,
        )
        try await loggerWithContext.logEvent(userActionEvent)
    }
    
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
        guard let profile = await profileStorage.getProfile() else {
            throw BotsiError.userProfileNotFound
        }
        let repository = UpdateRefundConsentRepository(httpClient: botsiClient)
        let useCase = BotsiUpdateRefundConsentUseCase(repository: repository)
        return try await useCase.execute(profileId: profile.profileId, consent: consent)
    }
}
