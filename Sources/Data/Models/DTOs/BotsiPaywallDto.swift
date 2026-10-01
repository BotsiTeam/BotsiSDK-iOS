//
//  BotsiPaywallDto.swift
//  Botsi
//

import Foundation

// MARK: - POST paywall

struct BotsiGetPaywallRequestDto: Encodable {
    let profileId: String
    let placementId: String
}

struct BotsiPaywallDto: Decodable {
    let id: Int
    let externalId: String?
    let name: String
    let isExperiment: Bool
    let aiPricingModelId: Int?
    let paywallSessionId: String
    let paywallProducts: [BotsiPaywallProduct]
}

// MARK: - POST events

struct BotsiPaywallShownEventRequestDto: Encodable {
    let eventType = "paywall_shown"
    let paywallSessionId: String
}
