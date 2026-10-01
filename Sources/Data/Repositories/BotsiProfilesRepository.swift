//
//  BotsiProfilesRepository.swift
//  Botsi
//

import Foundation

/// Profile calls on the Botsi V2 API.
struct BotsiProfilesRepository {
    let httpClient: BotsiHttpClient

    /// Creates a profile, or finds the existing one when `appUserId` is already known, and returns its ID.
    func createProfile(appUserId: String?, environment: BotsiEnvironment) async throws -> String {
        let body = BotsiCreateProfileRequestDto(appUserId: appUserId, environment: environment)
        let profile: BotsiCreatedProfileDto = try await httpClient.send(.post, "profiles", body: body)
        return profile.profileId
    }

    func getProfile(profileId: String) async throws -> BotsiProfile {
        try await httpClient.send(.get, "profiles/\(profileId.pathSegment)")
    }

    func updateProfile(profileId: String, update: BotsiUpdateProfileRequestDto) async throws -> BotsiProfile {
        try await httpClient.send(.patch, "profiles/\(profileId.pathSegment)", body: update)
    }

    /// Adds the attributes, or updates the value of those whose key already exists.
    func setCustomAttributes(profileId: String, entries: [BotsiProfile.BotsiCustomEntry]) async throws {
        let body = BotsiCustomAttributesRequestDto(
            profileId: profileId,
            custom: entries.map { .init(key: $0.key, value: $0.value) }
        )
        let _: [BotsiProfile.BotsiCustomEntry] = try await httpClient.send(.post, "custom-attributes", body: body)
    }

    func setAppleConsumptionConsent(profileId: String, consent: Bool) async throws {
        let body = BotsiAppleConsumptionConsentRequestDto(appleConsumptionConsent: consent)
        try await httpClient.send(.patch, "profiles/\(profileId.pathSegment)/apple-consumption-consent", body: body)
    }

    func sendAppleSearchAdsToken(profileId: String, token: String) async throws {
        let body = BotsiAppleSearchAdsRequestDto(profileId: profileId, token: token)
        try await httpClient.send(.post, "attribution/apple-search-ads", body: body)
    }
}
