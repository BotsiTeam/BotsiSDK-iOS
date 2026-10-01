//
//  BotsiPaywall.swift
//  Botsi
//
//  Created by Vladyslav on 22.03.2025.
//

import Foundation

/// The paywall Botsi chose for a placement, and the products it offers.
public struct BotsiPaywall: Sendable, Codable {
    /// The placement ID the paywall was fetched for.
    public let placementId: String
    public let id: Int
    public let externalId: String?
    public let name: String
    /// Whether AI pricing chose this paywall as an experiment.
    public let isExperiment: Bool
    /// The AI pricing model that chose the paywall, if one did.
    public let aiPricingModelId: Int?
    /// Links views and purchases to this paywall display. Report a view within about 24 hours of fetching.
    public let paywallSessionId: String
    public let products: [BotsiPaywallProduct]

    init(placementId: String, dto: BotsiPaywallDto) {
        self.placementId = placementId
        self.id = dto.id
        self.externalId = dto.externalId
        self.name = dto.name
        self.isExperiment = dto.isExperiment
        self.aiPricingModelId = dto.aiPricingModelId
        self.paywallSessionId = dto.paywallSessionId
        self.products = dto.paywallProducts
    }
}

public struct BotsiPaywallProduct: Sendable, Codable {
    public let paywallProductId: Int
    public let name: String
    /// Such as `monthly`, `annual`, `lifetime` or `consumable`.
    public let period: String
    /// The App Store product, or `nil` when the product isn't sold on the App Store.
    public let appStore: BotsiAppStoreProduct?
}

public struct BotsiAppStoreProduct: Sendable, Codable {
    public let productId: String
    /// The App Store offer attached to the product, if any.
    public let offerId: String?
    /// Same as `offerId` when the attached offer is promotional.
    public let promotionalOfferId: String?
    /// The attached offer's category, such as `promotional` or `win_back`.
    public let offerType: String?

    var winBackOfferId: String? {
        offerType == "win_back" ? offerId : nil
    }
}
