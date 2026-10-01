//
//  PaymentTransaction+Offer.swift
//  Botsi
//
//  Created by Vladyslav on 05.04.2025.
//

import StoreKit

public struct BotsiSubscriptionOffer: Sendable, CustomStringConvertible {
    
    public var description: String {
        return """
            Subscription Offer:
            
            id: \(id ?? "-")
            period: \(periodUnit.debugDescription)
            paymentMode: \(String(describing: type))
            offerType: \(String(describing: offerType))
            price: \(price ?? 0)
        """
    }
    
    public enum BotsiPaymentMode: String, Sendable {
        case payAsYouGo = "pay_as_you_go"
        case payUpFront = "pay_up_front"
        case freeTrial = "free_trial"
        case unknown = "unknown"
    }
    
    let id: String?
    let periodUnit: BotsiSubscriptionPeriod?
    let type: BotsiPaymentMode
    let offerType: BotsiPaymentTransaction.OfferType
    let price: Decimal?

    init(
        id: String,
        offerType: BotsiPaymentTransaction.OfferType
    ) {
        self.id = id
        periodUnit = nil
        type = .unknown
        self.offerType = offerType
        price = nil
    }
    
    init(
        id: String?,
        period: BotsiSubscriptionPeriod?,
        paymentMode: BotsiPaymentMode,
        offerType: BotsiPaymentTransaction.OfferType,
        price: Decimal?
    ) {
        self.id = id
        self.periodUnit = period
        self.type = paymentMode
        self.offerType = offerType
        self.price = price
    }
    
    init?(
        transaction: Transaction,
        product: Product?
    ) {
        guard let offerType = transaction.unfOfferType?.asPurchasedTransactionOfferType else { return nil }
        let productOffer = product?.subscriptionOffer(
            byType: offerType,
            withId: transaction.unfOfferId
        )
        self = .init(
            id: transaction.unfOfferId,
            period: .init(
                unit: (productOffer?.period)?.unit.toPeriodUnit ?? .unknown,
                numberOfUnits: (productOffer?.period)?.value ?? 0
            ),
            paymentMode: (productOffer?.paymentMode)?.asPaymentMode ?? .unknown,
            offerType: offerType,
            price: productOffer?.price
        )
    }
}

extension Transaction.OfferType {
    var asPurchasedTransactionOfferType: BotsiPaymentTransaction.OfferType {
        guard let type = BotsiPaymentTransaction.OfferType(rawValue: rawValue) else {
            return .unknown
        }
        return type
    }
}
