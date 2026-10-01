//
//  BotsiPaywallsRepository.swift
//  Botsi
//

import Foundation

/// Paywall calls on the Botsi V2 API.
struct BotsiPaywallsRepository {
    let httpClient: BotsiHttpClient

    func getPaywall(profileId: String, placementId: String) async throws -> BotsiPaywall {
        let body = BotsiGetPaywallRequestDto(profileId: profileId, placementId: placementId)
        let paywall: BotsiPaywallDto = try await httpClient.send(.post, "paywall", body: body)
        return BotsiPaywall(placementId: placementId, dto: paywall)
    }

    /// Reports one view of the paywall the session was issued for. The API accepts it for about 24 hours.
    func logPaywallShown(paywallSessionId: String) async throws {
        let body = BotsiPaywallShownEventRequestDto(paywallSessionId: paywallSessionId)
        try await httpClient.send(.post, "events", body: body)
    }
}
