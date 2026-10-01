//
//  BotsiProfile.swift
//  Botsi
//
//  Created by Vladyslav on 19.02.2025.
//

import Foundation

public struct BotsiProfile: Sendable, Codable {
    public let profileId: String
    /// Your own user ID for the profile, set through `activate(_:appUserId:)` or `identify(_:)`.
    public let appUserId: String?
    /// The subscription state, such as `subscribed`, `active-trial` or `billing-issue`.
    public let state: String?
    public let totalRevenueUsd: Double?
    public let accessLevels: [String: BotsiAccessLevel]
    public let subscriptions: [String: BotsiSubscription]
    public let nonSubscriptions: [String: BotsiNonSubscription]
    public let custom: [BotsiCustomEntry]
    
    /// Purchase and restore replies leave out custom attributes; the saved ones are kept for those.
    let includesCustom: Bool
    
    private enum CodingKeys: String, CodingKey {
        case profileId, appUserId, state, totalRevenueUsd, accessLevels, subscriptions, nonSubscriptions, custom
        /// The name SDK 1.x saved `appUserId` under.
        case customerUserId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        profileId = try container.decode(String.self, forKey: .profileId)
        appUserId = try container.decodeIfPresent(String.self, forKey: .appUserId)
            ?? container.decodeIfPresent(String.self, forKey: .customerUserId)
        // Informational only: a value the SDK can't read must not make the whole profile unreadable.
        state = (try? container.decodeIfPresent(String.self, forKey: .state)) ?? nil
        totalRevenueUsd = (try? container.decodeIfPresent(Double.self, forKey: .totalRevenueUsd)) ?? nil
        accessLevels = try container.decode([String: BotsiAccessLevel].self, forKey: .accessLevels)
        subscriptions = try container.decode([String: BotsiSubscription].self, forKey: .subscriptions)
        nonSubscriptions = try container.decode([String: BotsiNonSubscription].self, forKey: .nonSubscriptions)
        let decodedCustom = try container.decodeIfPresent([BotsiCustomEntry].self, forKey: .custom)
        custom = decodedCustom ?? []
        includesCustom = decodedCustom != nil
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(profileId, forKey: .profileId)
        try container.encodeIfPresent(appUserId, forKey: .appUserId)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(totalRevenueUsd, forKey: .totalRevenueUsd)
        try container.encode(accessLevels, forKey: .accessLevels)
        try container.encode(subscriptions, forKey: .subscriptions)
        try container.encode(nonSubscriptions, forKey: .nonSubscriptions)
        try container.encode(custom, forKey: .custom)
    }
    
    private init(_ profile: BotsiProfile, custom: [BotsiCustomEntry]) {
        self.profileId = profile.profileId
        self.appUserId = profile.appUserId
        self.state = profile.state
        self.totalRevenueUsd = profile.totalRevenueUsd
        self.accessLevels = profile.accessLevels
        self.subscriptions = profile.subscriptions
        self.nonSubscriptions = profile.nonSubscriptions
        self.custom = custom
        self.includesCustom = true
    }
    
    func withCustom(_ custom: [BotsiCustomEntry]) -> BotsiProfile {
        BotsiProfile(self, custom: custom)
    }
}

extension BotsiProfile: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(profileId)
        hasher.combine(appUserId)
    }
}

extension BotsiProfile: Equatable {
    public static func == (lhs: BotsiProfile, rhs: BotsiProfile) -> Bool {
        lhs.profileId == rhs.profileId && lhs.appUserId == rhs.appUserId
    }
}
