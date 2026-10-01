//
//  BotsiPaymentTransaction.swift
//  Botsi
//
//  Created by Vladyslav on 24.02.2025.
//

import StoreKit

public struct BotsiPaymentTransaction: Sendable, CustomStringConvertible {
    let transactionId: String
    let originalTransactionId: String
    let sourceProductId: String
    let originalPrice: Decimal?
    let priceLocale: String?
    let storeCountry: String?
    
    let offer: BotsiSubscriptionOffer?
    
    let promotionalOfferId: String
    let discountPrice: String
    let productId: String
    let environment: String
    
    let paywallId: Int?
    let abTestId: Int?
    let placementId: String?
    let isSubscription: Bool
    
    public var description: String {
        return """
            BotsiTransaction:
        
            transactionId: \(transactionId)
            originalTransactionId: \(originalTransactionId)
            vendorProductId: \(sourceProductId)
            price: \(originalPrice ?? 0)
            priceLocale: \(priceLocale ?? "-")
            storeCountry: \(storeCountry ?? "-")
            subscriptionOffer: \(offer.debugDescription)
        """
    }
}

extension BotsiPaymentTransaction {
    enum OfferType: Int, CustomStringConvertible {
        case unknown = 0
        case introductory = 1
        case promotional = 2
        case code = 3
        case winBack = 4
        
        var description: String {
            switch self {
            case .unknown:
                return "unknown"
            case .introductory:
                return "introductory"
            case .promotional:
                return "promotional"
            case .code:
                return "code"
            case .winBack:
                return "winBack"
            }
        }
    }
}

