//
//  BotsiProfileStorage.swift
//  Botsi
//
//  Created by Vladyslav on 12.03.2025.
//

import Foundation

public actor BotsiProfileStorage: Sendable {
    private let storageManager: BotsiStorageManager = BotsiStorageManager()
    
    private var profileId: String
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
            self.profileId = storedProfile.profileId
        } catch {
            self.profileId = BotsiProfileStorage.generateProfileId()
            self.profile = nil
        }
        
        
    }
    
    func currentProfileId() -> String {
        return profileId
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
    
    func getNewProfileUUID() -> String {
        let uuid = BotsiProfileStorage.generateProfileId()
        profileId = uuid
        return uuid
    }

    func getProfile(
        profileId: String,
        withCustomerUserId customerUserId: String?
    ) -> BotsiProfile? {
        guard let savedProfile = profile,
              savedProfile.profileId == profileId
        else {
            return nil
        }
        
        guard let customerUserId else {
            return savedProfile
        }
        
        return (customerUserId == savedProfile.customerUserId)
            ? savedProfile
            : nil
    }
    
    func setProfile(_ newProfile: BotsiProfile) async {
        do {
            try await storageManager.save(newProfile, forKey: UserDefaultKeys.User.userProfile)
            profile = newProfile
            profileId = newProfile.profileId
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
       
        profile = nil
        profileId = BotsiProfileStorage.generateProfileId()
        asaTokenUpdated = false
        syncedTransactions = false
       
        PaywallsStorage.clear()
        
        BotsiLog.debug("Profile cleared.")
    }
    
    private static func generateProfileId() -> String {
        let newId = UUID().uuidString.lowercased()
        return newId
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
        let repository = ASATokenRepository(httpClient: botsiClient)
        let useCase = BotsiASATokenUseCase(repository: repository)
        do {
            guard await !profileStorage.isASATokenUpdated() else { return }
            let token = try getASAToken()
            let updatedProfile = try await useCase.execute(profileId: profileId, token: token)
            await profileStorage.setProfile(updatedProfile)
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
