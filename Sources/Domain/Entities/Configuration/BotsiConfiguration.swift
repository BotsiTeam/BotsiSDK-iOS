//
//  BotsiConfiguration.swift
//  Botsi
//
//  Created by Vladyslav on 20.02.2025.
//

import Foundation

public struct BotsiConfiguration: Sendable {
    let sdkApiKey: String
    let appUserId: String?
}

public extension BotsiConfiguration {
    /// Starts a configuration with your app's public SDK key from the Botsi dashboard.
    static func build(sdkApiKey: String) -> Self {
        BotsiConfiguration(sdkApiKey: sdkApiKey, appUserId: nil)
    }
    
    /// Sets your own ID for the user, such as `user_1234`.
    func set(appUserId: String?) -> Self {
        BotsiConfiguration(sdkApiKey: sdkApiKey, appUserId: appUserId)
    }
}
