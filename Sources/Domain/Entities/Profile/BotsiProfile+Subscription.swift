//
//  BotsiSubscription.swift
//  Botsi
//
//  Created by Vladyslav on 19.02.2025.
//

import Foundation

extension BotsiProfile {
    public struct BotsiSubscription: Sendable, Hashable, Codable {
        public let createdDate: String
        public let id: Int
        public let isActive: Bool
        public let sourceProductId: String?
        public let store: String?
        public let activatedAt: String?
        public let isLifetime: Bool
        public let isRefund: Bool?
        public let willRenew: Bool
        public let isInGracePeriod: Bool
        public let cancellationReason: String?
        public let offerId: String?
        public let startsAt: Date?
        public let renewedAt: Date?
        public let expiresAt: Date?
        public let activeIntroductoryOfferType: String?
        public let activePromotionalOfferType: String?
        public let activePromotionalOfferId: String?
        public let unsubscribedAt: String?
        public let billingIssueDetectedAt: String?
        
        private enum CodingKeys: String, CodingKey {
            case createdDate, id, isActive, sourceProductId, store, activatedAt
            case isLifetime, isRefund, willRenew, isInGracePeriod, cancellationReason, offerId
            case startsAt, renewedAt, expiresAt, activeIntroductoryOfferType, activePromotionalOfferType
            case activePromotionalOfferId, unsubscribedAt, billingIssueDetectedAt
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            createdDate = try container.decode(String.self, forKey: .createdDate)
            id = try container.decode(Int.self, forKey: .id)
            isActive = try container.decode(Bool.self, forKey: .isActive)
            // These columns are nullable, for example on access granted from the dashboard.
            sourceProductId = try container.decodeIfPresent(String.self, forKey: .sourceProductId)
            store = try container.decodeIfPresent(String.self, forKey: .store)
            activatedAt = try container.decodeIfPresent(String.self, forKey: .activatedAt)
            isLifetime = try container.decodeIfPresent(Bool.self, forKey: .isLifetime) ?? false
            isRefund = try container.decodeIfPresent(Bool.self, forKey: .isRefund)
            willRenew = try container.decodeIfPresent(Bool.self, forKey: .willRenew) ?? false
            isInGracePeriod = try container.decodeIfPresent(Bool.self, forKey: .isInGracePeriod) ?? false
            cancellationReason = try container.decodeIfPresent(String.self, forKey: .cancellationReason)
            offerId = try container.decodeIfPresent(String.self, forKey: .offerId)
            
            startsAt = try container.decodeIfPresent(String.self, forKey: .startsAt).flatMap { try? Date.parseISO8601(from: $0) }
            renewedAt = try container.decodeIfPresent(String.self, forKey: .renewedAt).flatMap { try? Date.parseISO8601(from: $0) }
            expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt).flatMap { try? Date.parseISO8601(from: $0) }
            
            activeIntroductoryOfferType = try container.decodeIfPresent(String.self, forKey: .activeIntroductoryOfferType)
            activePromotionalOfferType = try container.decodeIfPresent(String.self, forKey: .activePromotionalOfferType)
            activePromotionalOfferId = try container.decodeIfPresent(String.self, forKey: .activePromotionalOfferId)
            unsubscribedAt = try container.decodeIfPresent(String.self, forKey: .unsubscribedAt)
            billingIssueDetectedAt = try container.decodeIfPresent(String.self, forKey: .billingIssueDetectedAt)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(createdDate, forKey: .createdDate)
            try container.encode(id, forKey: .id)
            try container.encode(isActive, forKey: .isActive)
            try container.encodeIfPresent(sourceProductId, forKey: .sourceProductId)
            try container.encodeIfPresent(store, forKey: .store)
            try container.encodeIfPresent(activatedAt, forKey: .activatedAt)
            try container.encode(isLifetime, forKey: .isLifetime)
            try container.encodeIfPresent(isRefund, forKey: .isRefund)
            try container.encode(willRenew, forKey: .willRenew)
            try container.encode(isInGracePeriod, forKey: .isInGracePeriod)
            try container.encodeIfPresent(cancellationReason, forKey: .cancellationReason)
            try container.encodeIfPresent(offerId, forKey: .offerId)
            
            try container.encodeIfPresent(startsAt?.toISO8601String(), forKey: .startsAt)
            try container.encodeIfPresent(renewedAt?.toISO8601String(), forKey: .renewedAt)
            try container.encodeIfPresent(expiresAt?.toISO8601String(), forKey: .expiresAt)
            
            try container.encodeIfPresent(activeIntroductoryOfferType, forKey: .activeIntroductoryOfferType)
            try container.encodeIfPresent(activePromotionalOfferType, forKey: .activePromotionalOfferType)
            try container.encodeIfPresent(activePromotionalOfferId, forKey: .activePromotionalOfferId)
            try container.encodeIfPresent(unsubscribedAt, forKey: .unsubscribedAt)
            try container.encodeIfPresent(billingIssueDetectedAt, forKey: .billingIssueDetectedAt)
        }
    }
}
