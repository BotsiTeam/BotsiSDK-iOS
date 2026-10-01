//
//  BotsiProduct.swift
//  Botsi
//
//  Created by Vladyslav on 23.03.2025.
//

import StoreKit

public protocol BotsiProduct: Sendable, CustomStringConvertible {
    
    var sk2Product: Product? { get }
    
    var paywallId: Int { get }
    var abTestId: Int? { get }
    var productId: String { get }
    var placementId: String? { get }
    
    var title: String { get }
    var descriptionText: String { get }
    
    var price: Decimal { get }
    var currencyCode: String? { get }
    var localizedPrice: String? { get }
    
    var isEligibleForIntroOffer: Bool { get }
    var introductoryPrice: String? { get }
    
    var subscriptionGroupIdentifier: String? { get }
    var localizedSubscriptionPeriod: String? { get }
    
    var subscriptionOffer: BotsiOffer? { get }
}

public extension BotsiProduct {
    var isEligibleForIntroOffer: Bool { false }
    var isEligibleForWinbackOffer: Bool { false }
    var isEligibleForPromotionalOffer: Bool { false }
    
    var introductoryOfferPrice: String? { nil }
    var promotionalOfferPrices: [String] { [] }
    var winbackOfferPrice: String? { nil }
}

// MARK: - SK2

protocol BotsiSK2Product: BotsiProduct {
    var skProduct: Product { get }
}

extension BotsiSK2Product {
    public var sk2Product: Product? { skProduct }
    
    var productId: String { skProduct.id }
    
    var title: String { skProduct.displayName }
    
    var descriptionText: String { skProduct.description }
    
    var price: Decimal { skProduct.price }
    
    var currencyCode: String? { skProduct.priceFormatStyle.currencyCode }
    
    var localizedPrice: String? { skProduct.displayPrice }
    
    var isEligibleForIntroOffer: Bool { skProduct.subscription?.introductoryOffer != nil }
    
    var introductoryPrice: String? {
        if let introOffer = skProduct.subscription?.introductoryOffer {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            return formatter.string(from: NSDecimalNumber(decimal: introOffer.price))
        } else {
            return nil
        }
    }
    
    var subscriptionGroupIdentifier: String? {
        if let sub = skProduct.subscription {
            return sub.subscriptionGroupID
        } else { return nil }
    }
    
    var localizedSubscriptionPeriod: String? {
        if let subPeriod = skProduct.subscription?.subscriptionPeriod {
            return "\(subPeriod.value) \(subPeriod.unit)"
        } else { return nil }
    }
    
    public var description: String {
        """
        SK2ProductDetails(
          productId: \(productId),
          title: "\(title)",
          descriptionText: "\(descriptionText)",
          price: \(price),
          currencyCode: \(currencyCode ?? "n/a"),
          localizedPrice: \(localizedPrice ?? "n/a"),
          introductoryPrice: \(introductoryPrice ?? "n/a"),
          isEligibleForIntroOffer: \(isEligibleForIntroOffer),
          subscriptionGroupIdentifier: \(subscriptionGroupIdentifier ?? "n/a")
        )
        """
    }
}

// MARK: - SK Products
struct BotsiSK2PaywallProduct: BotsiSK2Product {
    var skProduct: Product
    var paywallId: Int
    var placementId: String?
    var abTestId: Int?
    
    var subscriptionOffer: BotsiOffer?
}

extension Product {
    func unfWinBackOffer(byId identifier: String) -> Product.SubscriptionOffer? {
        #if compiler(<6.0)
        return nil
        #else
        
        guard #available(iOS 18.0, macOS 15.0, *) else {
            return nil
        }

        return subscription?.winBackOffers.first { $0.id == identifier }
        #endif
    }
    
    var introductoryOfferNotApplicable: Bool {
        subscription?.introductoryOffer == nil
    }
    
    private var unfIntroductoryOffer: Product.SubscriptionOffer? {
        subscription?.introductoryOffer
    }

    private func unfPromotionalOffer(byId identifier: String) -> Product.SubscriptionOffer? {
        subscription?.promotionalOffers.first(where: { $0.id == identifier })
    }
    
    @inlinable
    var unfPeriodLocale: Locale {
        subscriptionPeriodFormatStyle.locale
    }
    
    @inlinable
    var unfCurrencyCode: String? {
        priceFormatStyle.currencyCode
    }
    
    func subscriptionOffer(by offerIdentifier: BotsiOffer.Identifier) -> BotsiOffer? {
        let offer: Product.SubscriptionOffer? =
            switch offerIdentifier {
            case .introductory:
                unfIntroductoryOffer
            case .promotional(let id):
                unfPromotionalOffer(byId: id)
            case .winBack(let id):
                unfWinBackOffer(byId: id)
            }
        guard let offer else { return nil }

        let period = offer.period
        let periodLocale = unfPeriodLocale
        let subscriptionPeriod = BotsiSubscriptionPeriod(unit: period.unit.toPeriodUnit, numberOfUnits: period.value)
        
        return BotsiOffer(
            price: offer.price,
            currencyCode: unfCurrencyCode,
            localizedPrice: offer.displayPrice,
            offerIdentifier: offerIdentifier,
            subscriptionPeriod: subscriptionPeriod,
            numberOfPeriods: offer.periodCount,
            paymentMode: offer.paymentMode.asPaymentMode,
            localizedSubscriptionPeriod: periodLocale.localized(period: subscriptionPeriod),
            localizedNumberOfPeriods: periodLocale.localized(period: subscriptionPeriod, numberOfPeriods: offer.periodCount)
        )
    }
}
