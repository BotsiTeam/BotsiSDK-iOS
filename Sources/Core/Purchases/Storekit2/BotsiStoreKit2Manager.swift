//
//  BotsiStoreKit2Manager.swift
//  Botsi
//
//  Created by Vladyslav on 20.02.2025.
//

import StoreKit

public actor StoreKit2Handler {
    
    private let client: BotsiHttpClient
    private let storage: BotsiProfileStorage
    private let mapper: BotsiStoreKit2TransactionMapper = .init()
    private let paywallStorage: BotsiPaywallMappingStorage
    
    public init(client: BotsiHttpClient, storage: BotsiProfileStorage) {
        self.client = client
        self.storage = storage
        self.paywallStorage = BotsiPaywallMappingStorage()
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
                let repository = SignPromotionalOfferRepository(httpClient: client)
                let useCase = SignPromotionalOfferUseCase(repository: repository)
                do {
                    let signedOffer = try await useCase.getSignedPromotionalOffer(productId: product.productId, offerId: offerId)
                    
                    options = [
                        .promotionalOffer(
                            offerID: offerId,
                            keyID: signedOffer.keyId,
                            nonce: signedOffer.nonce,
                            signature: signedOffer.signature,
                            timestamp: Int(signedOffer.timestamp)!
                        )
                    ]
                } catch let error as BotsiError {
                    BotsiLog.warn("Failed to sign promotional offer \(offerId). Proceeding with the purchase without promo offer... \(error.localizedDescription)")
                    options = []
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
                let botsiTransaction = await mapper.completeTransaction(
                    with: transaction,
                    product: skProduct,
                    paywallId: product.paywallId,
                    abTestId: product.abTestId,
                    placementId: product.placementId
                )
                let profile = try await validateTransaction(
                    botsiTransaction,
                    source: .purchasing
                )
                let paywallMeta = PaywallMeta(
                    paywallId: product.paywallId,
                    placementId: product.placementId,
                    abTestId: product.abTestId
                )
                await paywallStorage.setPaywallMeta(
                    paywallMeta,
                    for: skProduct.id
                )
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
                        paywallId: current?.paywallId ?? cached?.paywallId ?? nil,
                        abTestId: nil,
                        placementId: current?.placementId ?? cached?.placementId
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
                    if let botsiError = error as? BotsiError {
                        BotsiLog.error("StoreKit 2 Error: \(botsiError.localizedDescription)")
                    } else {
                        let validationError = error as NSError
                        if validationError.isRetryableError() {
                            BotsiLog.error("StoreKit 2 Retrayable error: \(validationError.localizedDescription)")
                            processedTransactionIds.remove(transaction.id)
                            continue
                        } else {
                            BotsiLog.error("StoreKi 2 Validation error: \(validationError.localizedDescription)")
                        }
                    }
            
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
        guard let storedProfile = await storage.getProfile() else {
            throw BotsiError.customError("SK2.ValidateTransaction", "Unable to retrieve profile id")
        }
        let repository = ValidateTransactionRepository(
            httpClient: client,
            profileId: storedProfile.profileId
        )
        let profileFetched = try await repository.validateTransaction(
            transaction: transaction,
            source: source
        )
        await storage.setProfile(profileFetched)
        BotsiLog.info("StoreKit 2 Validate. Profile \(profileFetched.profileId) with access levels received: \(profileFetched.accessLevels.first?.key ?? "none")")
        return profileFetched
    }
    
    private func restoreTransactions() async throws -> BotsiProfile {
        guard let storedProfile = await storage.getProfile() else {
            throw BotsiError.customError("Restore transaction", "Unable to retrieve profile id")
        }
        let repository = RestorePurchaseRepository(httpClient: client, profileId: storedProfile.profileId)
        let helper = ReceiptRefreshHelper()
        var receipt: Data
        
        do {
            let receiptData = try await helper.refreshReceipt()
            receipt = receiptData
        } catch {
            guard let receiptURL = Bundle.main.appStoreReceiptURL else {
                throw BotsiError.customError("SK2. Restore.", "Unable to fetch receipt data from the app. The request could be throttled.")
            }
            let receiptData = try Data(contentsOf: receiptURL)
            receipt = receiptData
        }
        
        let profileFetched = try await repository.restore(receipt: receipt)
        await storage.setProfile(profileFetched)
        BotsiLog.info("StoreKit 2 Restore. Profile received after restoring transaction: \(profileFetched.profileId) with access levels: \(profileFetched.accessLevels.first?.key ?? "[]")")
        return profileFetched
    }

    public func restorePurchases() async throws -> BotsiProfile {
        return try await restoreTransactions()
    }
    
    public func refreshReceipt() async throws -> Data {
        let helper = ReceiptRefreshHelper()
        let receiptData = try await helper.refreshReceipt()
        return receiptData
    }
}

private extension NSError {
    func isRetryableError() -> Bool {
        if domain == NSURLErrorDomain {
            let retryableCodes: [Int] = [
                NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet
            ]
            return retryableCodes.contains(code)
        }
        
        if domain == "BotsiHTTPError" && code >= 500 && code < 600 {
            return true
        }
        
        return false
    }
}

enum StoreKitTransactionSource: String {
    case purchasing
    case observing
    case restore
}
