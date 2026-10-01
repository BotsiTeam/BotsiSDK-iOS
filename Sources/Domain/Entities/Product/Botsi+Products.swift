//
//  Botsi+Products.swift
//  Botsi
//
//  Created by Vladyslav on 19.04.2025.
//

import StoreKit

extension Botsi {
    func getBotsiProducts(
        paywall: BotsiPaywall,
        handler: StoreKit2Handler
    ) async throws -> [BotsiProduct] {
        
        let appStoreProducts = paywall.products.compactMap(\.appStore)
        let identifiers = appStoreProducts.map(\.productId)
        
        let products: [ProductTupleSK2] = try await handler.retrieveProductAsync(with: identifiers)
            .compactMap { sk2Product in
                let sourceProduct = appStoreProducts.first(where: { $0.productId == sk2Product.id })!
                let (offer, subscriptionGroupId): (BotsiOffer?, String?) =
                    if let subscriptionGroupId = sk2Product.subscription?.subscriptionGroupID,
                       winBackOfferExist(with: sourceProduct.winBackOfferId, from: sk2Product) {
                        (nil, subscriptionGroupId)
                    } else {
                        (subscriptionOfferAvailable(sourceProduct, sk2Product), nil)
                    }
                return (sk2Product, sourceProduct, offer, subscriptionGroupId)
            }
        let eligibleWinBackOfferIds = try await eligibleWinBackOfferIds(for: Set(products.compactMap { $0.subscriptionGroupId }))
        if !eligibleWinBackOfferIds.isEmpty {
            BotsiLog.verbose("Eligible for winback offers.")
        }

        var newProducts = [(product: Product, reference: BotsiAppStoreProduct, offer: BotsiOffer?)]()
        newProducts.reserveCapacity(products.count)
        for product in products {
            await newProducts.append(determineOfferFor(product, with: eligibleWinBackOfferIds))
        }

        return newProducts.map {
            BotsiSK2PaywallProduct(
                skProduct: $0.product,
                paywall: PaywallMeta(paywall: paywall),
                subscriptionOffer: $0.offer
            )
        }
    }

    private typealias ProductTupleSK2 = (
        product: Product,
        reference: BotsiAppStoreProduct,
        offer: BotsiOffer?,
        subscriptionGroupId: String?
    )

    private func subscriptionOfferAvailable(
        _ reference: BotsiAppStoreProduct,
        _ sk2Product: Product
    ) -> BotsiOffer? {
        if let promotionalOffer = promotionalOffer(with: reference.promotionalOfferId, from: sk2Product) {
            return promotionalOffer
        } else if sk2Product.introductoryOfferNotApplicable {
            return nil
        } else {
            return nil
        }
    }

    private func determineOfferFor(
        _ tuple: ProductTupleSK2,
        with eligibleWinBackOfferIds: [String: [String]]
    ) async -> (product: Product, reference: BotsiAppStoreProduct, offer: BotsiOffer?) {

        if let subscriptionGroupId = tuple.subscriptionGroupId,
           let winBackOfferId = tuple.reference.winBackOfferId
        {
            if eligibleWinBackOfferIds[subscriptionGroupId]?.contains(winBackOfferId) ?? false,
               let winBackOffer = winBackOffer(with: winBackOfferId, from: tuple.product)
            {
                
                return (tuple.product, tuple.reference, winBackOffer)
            }
        }
        
        if let subscription = tuple.product.subscription {
            let isIntroEligible = await subscription.isEligibleForIntroOffer
            if !isIntroEligible,
               let promoOffer = subscriptionOfferAvailable(tuple.reference, tuple.product)
            {
                BotsiLog.verbose("Promotional offer: \(promoOffer.description)")
                return (tuple.product, tuple.reference, promoOffer)
            }
        }
        
        if let subscription = tuple.product.subscription,
           let introductoryOffer = tuple.product.subscriptionOffer(by: .introductory)
        {
            let isIntroEligible = await subscription.isEligibleForIntroOffer
            if isIntroEligible {
                
                return (tuple.product, tuple.reference, introductoryOffer)
            }
        }
        
        return (tuple.product, tuple.reference, nil)
    }

    private func winBackOffer(with offerId: String?, from sk2Product: Product) -> BotsiOffer? {
        guard let offerId else { return nil }
        guard let offer = sk2Product.subscriptionOffer(by: .winBack(offerId)) else {
            BotsiLog.warn("no win back offer found with id:\(offerId) in productId:\(sk2Product.id)")
            return nil
        }
        return offer
    }

    private func promotionalOffer(with offerId: String?, from sk2Product: Product) -> BotsiOffer? {
        guard let offerId else { return nil }
        guard let offer = sk2Product.subscriptionOffer(by: .promotional(offerId)) else {
            BotsiLog.warn("no promotional offer found with id:\(offerId) in productId:\(sk2Product.id)")
            return nil
        }
        return offer
    }

    private func eligibleWinBackOfferIds(for subscriptionGroupIdentifiers: Set<String>) async throws -> [String: [String]] {
        var result = [String: [String]]()
        result.reserveCapacity(subscriptionGroupIdentifiers.count)
        for subscriptionGroupIdentifier in subscriptionGroupIdentifiers {
            result[subscriptionGroupIdentifier] = try await eligibleWinBackOfferIds(for: subscriptionGroupIdentifier)
        }
        return result
    }

    private func eligibleWinBackOfferIds(for subscriptionGroupIdentifier: String) async throws -> [String] {
        #if compiler(<6.0)
            return []
        #else
            guard #available(iOS 18.0, macOS 15.0, *) else { return [] }
            let statuses: [Product.SubscriptionInfo.Status]
            
            do {
                statuses = try await Product.SubscriptionInfo.status(for: subscriptionGroupIdentifier)
            } catch {
                BotsiLog.error("Status retrieving error: \(error.localizedDescription)")
                throw BotsiError.customError("winback", "error")
            }

            let status = statuses.first {
                guard case let .verified(transaction) = $0.transaction else { return false }
                guard transaction.ownershipType == .purchased else { return false }
                return true
            }

            guard case let .verified(renewalInfo) = status?.renewalInfo else { return [] }
            return renewalInfo.eligibleWinBackOfferIDs
        #endif
    }
    
    
    private func winBackOfferExist(with offerId: String?, from product: Product) -> Bool {
        guard let offerId else { return false }
        guard product.unfWinBackOffer(byId: offerId) != nil else {
            BotsiLog.info("No win back offer exists with identifier: \(offerId) for product: \(product.id)")
            return false
        }
        return true
    }
}
