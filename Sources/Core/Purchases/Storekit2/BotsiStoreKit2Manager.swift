//
//  BotsiStoreKit2Manager.swift
//  Botsi
//
//  Created by Vladyslav on 20.02.2025.
//

import StoreKit

public actor StoreKit2Handler {
    
    private let storage: BotsiProfileStorage
    private let profilesRepository: BotsiProfilesRepository
    private let purchasesRepository: BotsiPurchasesRepository
    private let mapper: BotsiStoreKit2TransactionMapper = .init()
    private let paywallStorage: BotsiPaywallMappingStorage
    
    public init(client: BotsiHttpClient, storage: BotsiProfileStorage) {
        self.storage = storage
        self.profilesRepository = BotsiProfilesRepository(httpClient: client)
        self.purchasesRepository = BotsiPurchasesRepository(httpClient: client)
        self.paywallStorage = BotsiPaywallMappingStorage()
    }
    
    /// Starts validating transactions StoreKit delivers outside a purchase: renewals, Ask to Buy approvals,
    /// purchases from other devices, and ones left unfinished. Call once a profile exists to validate them against.
    func startObservingTransactions() {
        Task {
            await self.startObservingTransactionUpdates()
        }
    }
    
    public func retrieveProductAsync(with productIDs: [String]) async throws -> [Product] {
        let products = try await Product.products(for: productIDs)
        BotsiLog.debug("SK2. Products retrieved: \(products.count)")
        guard let _ = products.first else {
            throw NSError(
                domain: "StoreKit2Handler",
                code: -2,
                userInfo: [
                    NSLocalizedDescriptionKey: "No matching StoreKit2 Product found."
                ]
            )
        }
        let sortedProducts = sortProducts(products, by: productIDs)
        return sortedProducts
    }
    
    private func sortProducts(_ products: [Product], by identifiers: [String]) -> [Product] {
        var productMap = [String: Product]()
        for product in products {
            productMap[product.id] = product
        }
        return identifiers.compactMap { productMap[$0] }
    }
    
    public func purchaseSK2(_ product: BotsiProduct) async throws -> BotsiProfile {
        guard let skProduct = product.sk2Product else {
            throw BotsiError.customError("SK2PurchaseError", "Unable to unwrap SK2 Product")
        }
        
        let options: Set<Product.PurchaseOption>
        
        switch product.subscriptionOffer {
        case .none:
            options = []
        case let .some(offer):
            switch offer.offerIdentifier {
            case .introductory:
                options = []
            case let .winBack(offerId):
                #if compiler(<6.0)
                throw BotsiError.customError("WinBackOffer purchase not available", "not supported")
                #else
                if #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *),
                   let winBackOffer = skProduct.unfWinBackOffer(byId: offerId)
                {
                    options = [.winBackOffer(winBackOffer)]
                } else {
                    throw BotsiError.customError("Error for SK2 winback offer", "not found")
                }
                #endif

            case let .promotional(offerId):
                do {
                    let signedOffer = try await purchasesRepository.promotionalSignature(
                        profileId: try await requireProfileId(),
                        productId: product.productId,
                        offerId: offerId
                    )
                    guard let signature = Data(base64Encoded: signedOffer.signature) else {
                        throw BotsiError.customError("SK2PromotionalOffer", "Signature isn't valid base64")
                    }
                    
                    options = [
                        .promotionalOffer(
                            offerID: offerId,
                            keyID: signedOffer.keyId,
                            nonce: signedOffer.nonce,
                            signature: signature,
                            timestamp: signedOffer.timestamp
                        )
                    ]
                } catch BotsiError.promoOfferNotConfigured {
                    // Buying without the offer would charge full price for a discount the paywall showed.
                    BotsiLog.error("Promotional offer \(offerId) can't be signed: \(BotsiError.promoOfferNotConfigured.localizedDescription)")
                    throw BotsiError.promoOfferNotConfigured
                } catch {
                    BotsiLog.warn("Failed to sign promotional offer \(offerId). Proceeding with the purchase without promo offer... \(error.localizedDescription)")
                    options = []
                }
            }
        }
        
        let result = try await skProduct.purchase(options: options)
        switch result {
        case .success(let verification):
            switch verification {
            case .unverified(_, let err):
                BotsiLog.info("StoreKit 2. Transaction unverified. \(err.localizedDescription)")
                throw BotsiError.transactionFailed
            case .verified(let transaction):
                BotsiLog.info("Transaction is OK. \(transaction.id)")
                let paywallMeta = (product as? BotsiSK2PaywallProduct)?.paywall
                let botsiTransaction = await mapper.completeTransaction(
                    with: transaction,
                    product: skProduct,
                    paywall: paywallMeta
                )
                let profile = try await validateTransaction(
                    botsiTransaction,
                    source: .purchasing
                )
                if let paywallMeta {
                    await paywallStorage.setPaywallMeta(
                        paywallMeta,
                        for: skProduct.id
                    )
                }
                await transaction.finish()
                return profile
            }
        case .userCancelled:
            BotsiLog.info("StoreKit 2. User cancelled the purchase.")
            throw BotsiError.transactionFailed
        case .pending:
            BotsiLog.info("StoreKit 2. Purchase deferred. Ignoring.")
            throw BotsiError.transactionDeferred
        @unknown default:
            BotsiLog.error("StoreKit 2. Unknown result.")
            throw BotsiError.transactionFailed
        }
    }
    
    private func startObservingTransactionUpdates() async {
        var processedTransactionIds = Set<UInt64>()
                
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                guard !processedTransactionIds.contains(transaction.id) else {
                    BotsiLog.debug("Skipping already processed transaction: \(transaction.id)")
                    continue
                }
                
                processedTransactionIds.insert(transaction.id)
                
                let isRenewal = transaction.isRenewal
                do {
                    let productId = transaction.productID
                    guard let product = try await Product.products(for: [productId]).first else {
                        throw BotsiError.customError(
                            "StoreKit2Handler",
                            "Unable to fetch product with id: \(productId)"
                        )
                    }
                    let (current, cached) = await paywallStorage.getPaywallMeta(for: productId)
                    let botsiTransaction = await mapper.completeTransaction(
                        with: transaction,
                        product: product,
                        paywall: current ?? cached
                    )
              
                    let updatedProfile = try await validateTransaction(
                        botsiTransaction,
                        source: .observing
                    )
                    await storage.setProfile(updatedProfile)
                    
                    BotsiLog.info("StoreKit 2. Transaction \(transaction.id) processed.")
                    
                    if isRenewal {
                        BotsiLog.info("StoreKit 2. Transaction \(transaction.id) renewal.")
                        await notifySubscriptionRenewal(product: product, profile: updatedProfile)
                    }
                        
                    await transaction.finish()
                } catch {
                    if error.isRetryable {
                        BotsiLog.error("StoreKit 2. Retryable error: \(error.localizedDescription)")
                        processedTransactionIds.remove(transaction.id)
                        continue
                    }
                    BotsiLog.error("StoreKit 2. Validation error: \(error.localizedDescription)")
                    await transaction.finish()
                }
                
            case .unverified(let transaction, let verificationError):
                BotsiLog.debug("StoreKit 2. Unverified transaction found. Error: \(verificationError.localizedDescription)")
                await transaction.finish()
            }
        }
    }
    
    /// `post notification to UI update`
    private func notifySubscriptionRenewal(product: Product, profile: BotsiProfile) async {}
    
    @discardableResult
    private func validateTransaction(_ transaction: BotsiPaymentTransaction, source: StoreKitTransactionSource) async throws -> BotsiProfile {
        let profileFetched = try await purchasesRepository.validateTransaction(
            transaction,
            profileId: try await requireProfileId(),
            source: source
        )
        await storage.setProfile(profileFetched)
        BotsiLog.info("StoreKit 2 Validate. Profile \(profileFetched.profileId) with access levels received: \(profileFetched.accessLevels.first?.key ?? "none")")
        return profileFetched
    }
    
    /// Restores the user's App Store subscription onto the current profile.
    ///
    /// The SDK sends the original transaction ID of the newest subscription StoreKit says the user is entitled to.
    /// With none, or when Botsi finds no subscription for it, the current profile is returned unchanged.
    ///
    /// - Parameter syncWithAppStore: `true` only when the user asked to restore, for example with a Restore
    ///   button. StoreKit then syncs the user's transactions and may ask them to sign in to the App Store.
    public func restorePurchases(syncWithAppStore: Bool = false) async throws -> BotsiProfile {
        let profileId = try await requireProfileId()
        if syncWithAppStore {
            do {
                try await AppStore.sync()
            } catch {
                BotsiLog.warn("StoreKit 2 Restore. App Store sync failed: \(error.localizedDescription)")
            }
        }
        
        let profile: BotsiProfile
        if let originalTransactionId = await latestSubscriptionOriginalTransactionId() {
            do {
                profile = try await purchasesRepository.restore(
                    profileId: profileId,
                    originalTransactionId: String(originalTransactionId)
                )
            } catch let error as BotsiError where error.apiErrorCode == BotsiAPIErrorCode.nothingToRestore {
                BotsiLog.info("StoreKit 2 Restore. Botsi found no subscription for transaction \(originalTransactionId).")
                profile = try await profilesRepository.getProfile(profileId: profileId)
            }
        } else {
            BotsiLog.info("StoreKit 2 Restore. StoreKit has no subscription to restore.")
            profile = try await profilesRepository.getProfile(profileId: profileId)
        }
        
        await storage.setProfile(profile)
        BotsiLog.info("StoreKit 2 Restore. Profile \(profile.profileId) with access levels: \(profile.accessLevels.first?.key ?? "[]")")
        return profile
    }
    
    /// The original transaction ID of the most recently bought auto-renewable subscription the user is entitled to.
    private func latestSubscriptionOriginalTransactionId() async -> UInt64? {
        var latest: Transaction?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.productType == .autoRenewable else {
                continue
            }
            if transaction.purchaseDate > latest?.purchaseDate ?? .distantPast {
                latest = transaction
            }
        }
        return latest?.originalID
    }
    
    private func requireProfileId() async throws -> String {
        guard let profileId = await storage.currentProfileId() else {
            throw BotsiError.userProfileNotFound
        }
        return profileId
    }
}

private extension Error {
    /// Network failures, rate limiting and server faults can succeed on a later attempt, as can a
    /// transaction that arrives before a profile exists to validate it against.
    var isRetryable: Bool {
        if let botsiError = self as? BotsiError {
            if case .userProfileNotFound = botsiError {
                return true
            }
            return botsiError.isRetryableAPIError
        }
        if let urlError = self as? URLError {
            return [.timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet].contains(urlError.code)
        }
        return false
    }
}

enum StoreKitTransactionSource: String {
    case purchasing
    case observing
    case restore
}
