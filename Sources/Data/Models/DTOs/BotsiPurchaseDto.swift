//
//  BotsiPurchaseDto.swift
//  Botsi
//

import Foundation

// MARK: - POST purchases/apple-store/validate

struct BotsiValidateTransactionRequestDto: Encodable {
    let profileId: String
    let productId: String
    let transactionId: String
    let originalTransactionId: String
    let source: String
    /// `sandbox` or `production`. Left out for Xcode test transactions, which the API rejects as an environment.
    let environment: String?
    let isSubscription: Bool
    let offer: Offer?
    let placementId: String?
    let paywallId: Int?
    let isExperiment: Bool?
    let aiPricingModelId: Int?
    /// Attributes the purchase to the paywall display. When it's sent, the API takes the paywall,
    /// placement, A/B test and AI pricing fields from it alone, so the explicit ones are left out.
    let paywallSessionId: String?

    struct Offer: Encodable {
        let periodUnit: String?
        let numberOfUnits: Int?
        let type: String?
        let category: String?
    }

    /// - Parameter useSession: `false` sends the explicit paywall fields in place of a paywall session
    ///   the API rejected.
    init(transaction: BotsiPaymentTransaction, profileId: String, source: StoreKitTransactionSource, useSession: Bool = true) {
        self.profileId = profileId
        self.productId = transaction.productId
        self.transactionId = transaction.transactionId
        self.originalTransactionId = transaction.originalTransactionId
        self.source = source.rawValue
        self.environment = ["sandbox", "production"].contains(transaction.environment) ? transaction.environment : nil
        self.isSubscription = transaction.isSubscription
        if let offer = transaction.offer, offer.offerType != .unknown {
            self.offer = Offer(
                periodUnit: offer.periodUnit?.unit.rawValue,
                numberOfUnits: offer.periodUnit?.numberOfUnits,
                type: offer.type.rawValue,
                category: offer.offerType.apiCategory
            )
        } else {
            self.offer = nil
        }
        let paywall = transaction.paywall
        let paywallSessionId = useSession ? paywall?.paywallSessionId : nil
        self.paywallSessionId = paywallSessionId
        if paywallSessionId == nil {
            self.placementId = paywall?.placementId
            self.paywallId = paywall?.paywallId
            self.isExperiment = paywall?.isExperiment
            self.aiPricingModelId = paywall?.aiPricingModelId
        } else {
            self.placementId = nil
            self.paywallId = nil
            self.isExperiment = nil
            self.aiPricingModelId = nil
        }
    }
}

private extension BotsiPaymentTransaction.OfferType {
    /// The API's offer category: `introductory`, `promotional`, `code`, `win_back` or `unknown`.
    var apiCategory: String {
        switch self {
        case .winBack: "win_back"
        default: description
        }
    }
}

// MARK: - POST purchases/apple-store/restore

struct BotsiRestoreRequestDto: Encodable {
    let profileId: String
    let originalTransactionId: String
}

// MARK: - POST offers/apple-store/promotional-signature

struct BotsiPromotionalSignatureRequestDto: Encodable {
    let profileId: String
    let productId: String
    let offerId: String
}

struct BotsiPromotionalSignatureDto: Decodable {
    let keyId: String
    let nonce: UUID
    /// Milliseconds since 1970.
    let timestamp: Int
    /// Base64-encoded.
    let signature: String
}
