//
//  PaymentTransaction+Extension.swift
//  Botsi
//
//  Created by Vladyslav on 05.04.2025.
//

import StoreKit

extension BotsiPaymentTransaction {
    
    init(with product: Product,
         transaction: Transaction,
         paywall: PaywallMeta? = nil
    ) {
        let offer = BotsiSubscriptionOffer(transaction: transaction, product: product)
        self.transactionId = String(transaction.id)
        self.originalTransactionId = String(transaction.originalID)
        self.sourceProductId = transaction.productID
        self.originalPrice = Decimal(string: product.price.description)
        self.priceLocale = product.priceFormatStyle.currencyCode
        self.storeCountry = Locale.current.region?.identifier
        switch transaction.environment {
        case .sandbox:
            self.environment = "sandbox"
        case .production:
            self.environment = "production"
        default:
            self.environment = "unknown"
        }
        self.offer = offer
        self.promotionalOfferId = offer?.id ?? ""
        self.discountPrice = "\(offer?.price ?? 0)"
        self.productId = product.id
        self.paywall = paywall
        self.isSubscription = offer != nil
    }
}

/// `StoreKit 2`
extension Transaction {
    var isRenewal: Bool {
        return originalID != id
    }
    
    var unfOfferType: Transaction.OfferType? {
        #if compiler(>=5.9.2) && (!os(visionOS) || compiler(>=5.10))
            if #available(iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2, visionOS 1.1, *) {
                return offer?.type
            }
        #endif
        return offerType
    }
    
    var unfOfferId: String? {
        #if compiler(>=5.9.2) && (!os(visionOS) || compiler(>=5.10))
            if #available(iOS 17.2, macOS 14.2, tvOS 17.2, watchOS 10.2, visionOS 1.1, *) {
                return offer?.id
            }
        #endif
        return offerID
    }
}

extension Product {
    func subscriptionOffer(
        byType offerType: BotsiPaymentTransaction.OfferType,
        withId offerId: String?
    ) -> Product.SubscriptionOffer? {
        guard let subscription else { return nil }

        switch offerType {
        case .introductory:
            return subscription.introductoryOffer
        case .promotional:
            if let offerId {
                return subscription.promotionalOffers.first { $0.id == offerId }
            }
        case .code:
            return nil
        case .winBack:
            #if compiler(>=6)
                if #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *), let offerId {
                    return subscription.winBackOffers.first { $0.id == offerId }
                }
            #endif
        default:
            return nil
        }

        return nil
    }
}
