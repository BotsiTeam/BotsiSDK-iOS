//
//  BotsiProfileStorage.swift
//  Botsi
//
//  Created by Vladyslav on 12.03.2025.
//

import Foundation

public actor BotsiProfileStorage: Sendable {
    private let storageManager: BotsiStorageManager = BotsiStorageManager()
    
    private var profile: BotsiProfile?
    private var asaTokenUpdated: Bool = false
    
    private var externalAnalyticsDisabled: Bool = false
    private var syncedTransactions: Bool = false

    init() async {
        do {
            guard let storedProfile = try await storageManager.retrieve(BotsiProfile.self, forKey: UserDefaultKeys.User.userProfile) else {
                throw BotsiError.customError("Profile Storage Error.", "Unable to retrieve user profile")
            }
            self.profile = storedProfile
        } catch {
            self.profile = nil
        }
    }

    /// The saved profile's ID, or `nil` before a profile has been created.
    func currentProfileId() -> String? {
        return profile?.profileId
    }
    
    func isExternalAnalyticsDisabled() -> Bool {
        return externalAnalyticsDisabled
    }
    
    func hasSyncedTransactions() -> Bool {
        return syncedTransactions
    }
    
    func getProfile() -> BotsiProfile? {
        return profile
    }
    
    /// Saves `newProfile` when there's no current profile or it is the current one. A late reply for a
    /// profile the user has since left is ignored.
    func setProfile(_ newProfile: BotsiProfile) async {
        var newProfile = newProfile
        if let profile {
            guard profile.profileId == newProfile.profileId else {
                BotsiLog.debug("Ignoring profile \(newProfile.profileId): \(profile.profileId) is current.")
                return
            }
            if !newProfile.includesCustom {
                newProfile = newProfile.withCustom(profile.custom)
            }
        }
        do {
            try await storageManager.save(newProfile, forKey: UserDefaultKeys.User.userProfile)
            profile = newProfile
            BotsiLog.debug("Profile updated successfully with ID: \(newProfile.profileId)")
        } catch {
            BotsiLog.error("Failed to save profile. \(error.localizedDescription)")
        }
    }
    
    func setSyncedTransactions(_ value: Bool) async throws {
        guard syncedTransactions != value else { return }
        syncedTransactions = value
        
        try await storageManager.save(value, forKey: UserDefaultKeys.User.syncedTransactions)
        
        BotsiLog.debug("Set syncedTransactions = \(value)")
    }
    
    func clearProfile() async {
        BotsiLog.debug("Clearing profile...")
        
        await storageManager.delete(forKey: UserDefaultKeys.User.userProfile)
        await storageManager.delete(forKey: UserDefaultKeys.User.syncedTransactions)
        await storageManager.delete(forKey: UserDefaultKeys.User.lastSyncedTransactionId)
        await storageManager.delete(forKey: UserDefaultKeys.User.asaToken)
        await storageManager.delete(forKey: UserDefaultKeys.User.environment)

        profile = nil
        asaTokenUpdated = false
        syncedTransactions = false
       
        PaywallsStorage.clear()
        
        BotsiLog.debug("Profile cleared.")
    }

    /// The device and app details last sent to Botsi for the saved profile.
    func savedEnvironment() async -> BotsiEnvironment? {
        try? await storageManager.retrieve(BotsiEnvironment.self, forKey: UserDefaultKeys.User.environment)
    }

    func setSavedEnvironment(_ environment: BotsiEnvironment) async {
        try? await storageManager.save(environment, forKey: UserDefaultKeys.User.environment)
    }

    func setASATokenUpdated(_ value: Bool) async {
        BotsiLog.debug("ASA token updated: \(value)")
        try? await storageManager.save(value, forKey: UserDefaultKeys.User.asaToken)
    }
    
    func isASATokenUpdated() async -> Bool {
        do {
            guard let asaTokenUpdated = try await storageManager.retrieve(Bool.self, forKey: UserDefaultKeys.User.asaToken) else {
                BotsiLog.warn("ASA token not found.")
                return false
            }
            return asaTokenUpdated
        } catch {
            return false
        }
    }
}

enum PaywallsStorage {
    static func clear() {
        BotsiLog.debug("Cleared PaywallsStorage.")
    }
}

import AdServices

public extension Botsi {
    func updateASAToken(_ profileId: String) async {
        do {
            guard await !profileStorage.isASATokenUpdated() else { return }
            let token = try getASAToken()
            try await profilesRepository.sendAppleSearchAdsToken(profileId: profileId, token: token)
            await profileStorage.setASATokenUpdated(true)
        } catch let error as BotsiError {
            BotsiLog.warn("ASA token update failed with botsi error: \(error.localizedDescription)")
        } catch {
            BotsiLog.warn("ASA token update failed with error: \(error.localizedDescription)")
        }
    }
    
    func getASAToken() throws -> String {
        do {
            let attributionToken = try AAAttribution.attributionToken()
            return attributionToken
        } catch {
            throw error
        }
    }
}
