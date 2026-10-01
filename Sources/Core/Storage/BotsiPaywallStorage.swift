//
//  BotsiPaywallMappingStorage.swift
//  Botsi
//
//  Created by Vladyslav on 05.04.2025.
//

import Foundation

/// The paywall a purchase came from, sent with its validation so Botsi can attribute it.
struct PaywallMeta: Codable, Equatable {
    let paywallId: Int
    let placementId: String?
    let isExperiment: Bool?
    let aiPricingModelId: Int?
    let paywallSessionId: String?
    
    init(paywall: BotsiPaywall) {
        self.paywallId = paywall.id
        self.placementId = paywall.placementId
        self.isExperiment = paywall.isExperiment
        self.aiPricingModelId = paywall.aiPricingModelId
        self.paywallSessionId = paywall.paywallSessionId
    }
}

@BotsiPaywallMappingStorage.InternalActor
final class BotsiPaywallMappingStorage: Sendable {
    
    nonisolated init() { }
    
    @globalActor
    actor InternalActor {
        public static let shared = InternalActor()
    }

    enum Constants {
        static let paywalls = "current_botsi_paywalls"
        static let cachedPaywalls = "cached_botsi_paywalls"
    }

    private static let storage = UserDefaults.standard
    
    private static var paywalls: [String: PaywallMeta] {
        get {
            guard let data = storage.data(forKey: Constants.paywalls) else { return [:] }
            do {
                return try JSONDecoder().decode([String: PaywallMeta].self, from: data)
            } catch {
                return [:]
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                storage.set(data, forKey: Constants.paywalls)
            } catch {
                BotsiLog.error("Failed to encode paywalls: \(error)")
            }
        }
    }

    private static var cachedPaywalls: [String: PaywallMeta] {
        get {
            guard let data = storage.data(forKey: Constants.cachedPaywalls) else { return [:] }
            do {
                return try JSONDecoder().decode([String: PaywallMeta].self, from: data)
            } catch {
                return [:]
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                storage.set(data, forKey: Constants.cachedPaywalls)
            } catch {
                BotsiLog.error("Failed to encode cached paywalls: \(error)")
            }
        }
    }

    fileprivate var paywalls: [String: PaywallMeta] { Self.paywalls }
    fileprivate var cachedPaywalls: [String: PaywallMeta] { Self.cachedPaywalls }
    
    static func clear() {
        paywalls = [:]
        cachedPaywalls = [:]
        storage.removeObject(forKey: Constants.paywalls)
        storage.removeObject(forKey: Constants.cachedPaywalls)
    }

    @discardableResult
    fileprivate func setPersistentPaywallMetadata(_ meta: PaywallMeta, for productId: String) -> Bool {
        var dict = Self.cachedPaywalls
        let oldMeta = dict.updateValue(meta, forKey: productId)
        guard oldMeta != meta else { return false }
        
        Self.cachedPaywalls = dict
        return true
    }

    @discardableResult
    fileprivate func setPaywallMetadata(_ meta: PaywallMeta, for productId: String) -> Bool {
        var dict = Self.paywalls
        let oldMeta = dict.updateValue(meta, forKey: productId)
        guard oldMeta != meta else { return false }
        
        Self.paywalls = dict
        return true
    }

    fileprivate func removePaywallMetadata(for productId: String) -> Bool {
        var dict = Self.paywalls
        guard let _ = dict.removeValue(forKey: productId) else { return false }
        
        Self.paywalls = dict
        return true
    }
    
    nonisolated func getPaywallMeta(for productId: String) async -> (current: PaywallMeta?, cached: PaywallMeta?) {
        await (paywalls[productId], cachedPaywalls[productId])
    }
    
    nonisolated func setPaywallMeta(_ meta: PaywallMeta, for productId: String) async {
        Task {
            await setPaywallMetadata(meta, for: productId)
            await setPersistentPaywallMetadata(meta, for: productId)
        }
    }

    nonisolated func setPaywallMeta(_ meta: PaywallMeta, for productIds: [String]) async {
        guard !productIds.isEmpty else { return }
        
        for productId in productIds {
            await setPaywallMetadata(meta, for: productId)
        }
    }
    
    nonisolated func removePaywallMapping(for productId: String) async {
        Task {
            guard await removePaywallMetadata(for: productId) else { return }
        }
    }
    
    nonisolated func hasPaywallMapping(productId: String) async -> Bool {
        let (current, _) = await getPaywallMeta(for: productId)
        return current != nil
    }
    
    static func getProductIds(for paywallId: Int) -> [String] {
        return paywalls
            .filter { $1.paywallId == paywallId }
            .map { $0.key }
    }
}
