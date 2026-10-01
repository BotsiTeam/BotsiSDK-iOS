//
//  BotsiProfileDto.swift
//  Botsi
//

import Foundation

// MARK: - POST profiles

struct BotsiCreateProfileRequestDto: Encodable {
    let appUserId: String?
    let country: String
    let device: String
    let os: String
    let platform: String
    let appVersion: String
    let appBuild: String?
    let locale: String?

    init(appUserId: String?, environment: BotsiEnvironment) {
        self.appUserId = appUserId
        self.country = environment.country
        self.device = environment.device
        self.os = environment.os
        self.platform = environment.platform
        self.appVersion = environment.appVersion
        self.appBuild = environment.appBuild
        self.locale = environment.locale
    }
}

struct BotsiCreatedProfileDto: Decodable {
    let profileId: String
}

// MARK: - PATCH profiles/{profileId}

/// Only the fields that are set are sent; the API leaves the others unchanged.
struct BotsiUpdateProfileRequestDto: Encodable {
    var email: String?
    var phone: String?
    var username: String?
    var gender: String?
    /// `yyyy-MM-dd`
    var birthday: String?
    var idfa: String?
    var advertisingId: String?
    var ipAddress: String?
    var device: String?
    var os: String?
    var appVersion: String?
    var appBuild: String?
    var locale: String?
    var country: String?

    init(_ information: BotsiUserProfileInformation) {
        self.email = information.email
        self.phone = information.phone
        self.username = information.username
        self.gender = information.gender?.rawValue
        self.birthday = information.birthday.map(Self.birthdayFormatter.string(from:))
        self.idfa = information.idfa
        self.advertisingId = information.advertisingId
        self.ipAddress = information.ipAddress
    }

    init(_ environment: BotsiEnvironment) {
        self.device = environment.device
        self.os = environment.os
        self.appVersion = environment.appVersion
        self.appBuild = environment.appBuild
        self.locale = environment.locale
        self.country = environment.country
    }

    private static let birthdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - POST custom-attributes

struct BotsiCustomAttributesRequestDto: Encodable {
    let profileId: String
    let custom: [Entry]

    struct Entry: Encodable {
        let key: String
        let value: String
    }
}

// MARK: - PATCH profiles/{profileId}/apple-consumption-consent

struct BotsiAppleConsumptionConsentRequestDto: Encodable {
    let appleConsumptionConsent: Bool
}

// MARK: - POST attribution/apple-search-ads

struct BotsiAppleSearchAdsRequestDto: Encodable {
    let profileId: String
    let token: String
}
