//
//  BotsiProfileUpdate.swift
//  Botsi
//
//  Created by Vladyslav on 27.05.2025.
//

import Foundation

public struct BotsiUserProfileInformation: Sendable {
    public let birthday: Date?
    public let email: String?
    public let username: String?
    public let gender: BotsiGender?
    public let phone: String?
    public let custom: [BotsiProfile.BotsiCustomEntry]?
    public let idfa: String?
    public let advertisingId: String?
    internal let ipAddress: String?
    
    public init(
        birthday: Date? = nil,
        email: String? = nil,
        username: String? = nil,
        gender: BotsiGender? = nil,
        phone: String? = nil,
        custom: [BotsiProfile.BotsiCustomEntry]? = nil,
        idfa: String? = nil,
        advertisingId: String? = nil,
        ipAddress: String? = nil
    ) {
        self.birthday = birthday
        self.email = email
        self.username = username
        self.gender = gender
        self.phone = phone
        self.custom = custom
        self.idfa = idfa
        self.advertisingId = advertisingId
        self.ipAddress = ipAddress
    }
} 
