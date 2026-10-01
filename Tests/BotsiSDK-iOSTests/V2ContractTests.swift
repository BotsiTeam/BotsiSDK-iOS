import Testing
import Foundation
@testable import Botsi

// Request bodies must use the field names the Botsi V2 API declares, and replies in the shapes it sends.
// Field lists come from the API's request classes (api/src/web-api/v2 in the backend repo).

private func jsonObject(_ value: some Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

private let environment = BotsiEnvironment(
    country: "USA",
    device: "iPhone17,2",
    os: "26.5",
    platform: "ios",
    appVersion: "2.0.0",
    appBuild: "412",
    locale: "en"
)

private let paywallJSON = """
{
  "id": 42,
  "externalId": "premium",
  "name": "Premium",
  "isExperiment": true,
  "aiPricingModelId": 32,
  "paywallSessionId": "v2.session",
  "paywallProducts": [
    {
      "paywallProductId": 907,
      "name": "Premium Monthly",
      "period": "monthly",
      "appStore": { "productId": "com.example.monthly", "offerId": "winback-1", "promotionalOfferId": null, "offerType": "win_back" },
      "playStore": { "productId": "premium_monthly", "basePlanId": "monthly-base", "offerId": null },
      "stripe": null,
      "web2wave": null,
      "custom": null
    },
    {
      "paywallProductId": 908,
      "name": "Web only",
      "period": "annual",
      "appStore": null,
      "playStore": null,
      "stripe": { "productId": "prod_1", "priceId": "price_1", "trialPeriodDays": 7 },
      "web2wave": null,
      "custom": null
    }
  ]
}
"""

// MARK: - Requests

@Test func createProfileSendsTheDeclaredFields() throws {
    let body = try jsonObject(BotsiCreateProfileRequestDto(appUserId: "user-1", environment: environment))

    #expect(Set(body.keys) == ["appUserId", "country", "device", "os", "platform", "appVersion", "appBuild", "locale"])
    #expect(body["country"] as? String == "USA")
    #expect(body["platform"] as? String == "ios")
}

@Test func anonymousProfileLeavesOutAppUserId() throws {
    let body = try jsonObject(BotsiCreateProfileRequestDto(appUserId: nil, environment: environment))

    #expect(body["appUserId"] == nil)
}

@Test func profileUpdateSendsOnlyTheFieldsGiven() throws {
    var birthday = DateComponents()
    birthday.year = 1990
    birthday.month = 4
    birthday.day = 12
    let information = BotsiUserProfileInformation(
        birthday: Calendar.current.date(from: birthday),
        email: "ada@example.com",
        gender: .female,
        ipAddress: "203.0.113.7"
    )

    let body = try jsonObject(BotsiUpdateProfileRequestDto(information))

    #expect(Set(body.keys) == ["birthday", "email", "gender", "ipAddress"])
    #expect(body["birthday"] as? String == "1990-04-12")
    #expect(body["gender"] as? String == "female")
}

@Test func environmentUpdateSendsDeviceAndAppDetails() throws {
    let body = try jsonObject(BotsiUpdateProfileRequestDto(environment))

    #expect(Set(body.keys) == ["device", "os", "appVersion", "appBuild", "locale", "country"])
}

@Test func paywallShownEventSendsExactlyTwoFields() throws {
    // V2 rejects any other field on this event with a 400.
    let body = try jsonObject(BotsiPaywallShownEventRequestDto(paywallSessionId: "v2.session"))

    #expect(Set(body.keys) == ["eventType", "paywallSessionId"])
    #expect(body["eventType"] as? String == "paywall_shown")
}

@Test func validateSendsTransactionAndPaywallContext() throws {
    let paywall = BotsiPaywall(placementId: "onboarding", dto: try decode(BotsiPaywallDto.self, paywallJSON))
    let transaction = BotsiPaymentTransaction(
        transactionId: "2000000001",
        originalTransactionId: "2000000000",
        sourceProductId: "com.example.monthly",
        originalPrice: 9.99,
        priceLocale: "USD",
        storeCountry: "US",
        offer: nil,
        promotionalOfferId: "",
        discountPrice: "0",
        productId: "com.example.monthly",
        environment: "sandbox",
        paywall: PaywallMeta(paywall: paywall),
        isSubscription: true
    )

    let body = try jsonObject(BotsiValidateTransactionRequestDto(transaction: transaction, profileId: "p1", source: .purchasing))

    // The API takes the paywall fields from the session alone and counts any it's sent as disagreements.
    #expect(Set(body.keys) == [
        "profileId", "productId", "transactionId", "originalTransactionId", "source", "environment",
        "isSubscription", "paywallSessionId"
    ])
    #expect(body["source"] as? String == "purchasing")
    #expect(body["paywallSessionId"] as? String == "v2.session")

    // A session the API rejects is replaced by the explicit fields.
    let explicitBody = try jsonObject(BotsiValidateTransactionRequestDto(
        transaction: transaction,
        profileId: "p1",
        source: .observing,
        useSession: false
    ))
    #expect(explicitBody["paywallSessionId"] == nil)
    #expect(explicitBody["placementId"] as? String == "onboarding")
    #expect(explicitBody["paywallId"] as? Int == 42)
    #expect(explicitBody["isExperiment"] as? Bool == true)
    #expect(explicitBody["aiPricingModelId"] as? Int == 32)
}

@Test func validateLeavesOutAnEnvironmentTheAPIRejects() throws {
    let transaction = BotsiPaymentTransaction(
        transactionId: "1",
        originalTransactionId: "1",
        sourceProductId: "com.example.monthly",
        originalPrice: nil,
        priceLocale: nil,
        storeCountry: nil,
        offer: nil,
        promotionalOfferId: "",
        discountPrice: "0",
        productId: "com.example.monthly",
        environment: "unknown",
        paywall: nil,
        isSubscription: false
    )

    let body = try jsonObject(BotsiValidateTransactionRequestDto(transaction: transaction, profileId: "p1", source: .observing))

    #expect(body["environment"] == nil)
    #expect(body["paywallId"] == nil)
}

@Test func restoreAndOfferSignatureSendTheDeclaredFields() throws {
    let restore = try jsonObject(BotsiRestoreRequestDto(profileId: "p1", originalTransactionId: "2000000000"))
    let signature = try jsonObject(BotsiPromotionalSignatureRequestDto(profileId: "p1", productId: "com.example.monthly", offerId: "promo"))
    let searchAds = try jsonObject(BotsiAppleSearchAdsRequestDto(profileId: "p1", token: "token"))
    let consent = try jsonObject(BotsiAppleConsumptionConsentRequestDto(appleConsumptionConsent: true))

    #expect(Set(restore.keys) == ["profileId", "originalTransactionId"])
    #expect(Set(signature.keys) == ["profileId", "productId", "offerId"])
    #expect(Set(searchAds.keys) == ["profileId", "token"])
    #expect(Set(consent.keys) == ["appleConsumptionConsent"])
}

// MARK: - Replies

@Test func paywallKeepsOnlyAppStoreDetails() throws {
    let paywall = BotsiPaywall(placementId: "onboarding", dto: try decode(BotsiPaywallDto.self, paywallJSON))

    #expect(paywall.placementId == "onboarding")
    #expect(paywall.paywallSessionId == "v2.session")
    #expect(paywall.products.count == 2)
    #expect(paywall.products.compactMap(\.appStore).map(\.productId) == ["com.example.monthly"])
    #expect(paywall.products.first?.appStore?.winBackOfferId == "winback-1")
}

@Test func profileReadIncludesCustomAttributes() throws {
    let profile = try decode(BotsiProfile.self, """
    {
      "profileId": "p1",
      "appUserId": "user-1",
      "state": "subscribed",
      "totalRevenueUsd": 9.99,
      "accessLevels": {},
      "subscriptions": {},
      "nonSubscriptions": {},
      "custom": [{ "id": "a1", "key": "user_level", "value": "premium" }]
    }
    """)

    #expect(profile.appUserId == "user-1")
    #expect(profile.state == "subscribed")
    #expect(profile.custom.map(\.key) == ["user_level"])
    #expect(profile.includesCustom)
}

@Test func purchaseReplyWithoutCustomAttributesIsMarked() throws {
    // Validate and restore replies leave out `custom`; storage keeps the saved attributes for them.
    let profile = try decode(BotsiProfile.self, """
    {
      "profileId": "p1",
      "appUserId": null,
      "state": "never-subscribed",
      "totalRevenueUsd": 0,
      "accessLevels": {},
      "subscriptions": {},
      "nonSubscriptions": {}
    }
    """)

    #expect(!profile.includesCustom)

    let merged = profile.withCustom([.init(key: "user_level", value: "premium", id: "a1")])
    #expect(merged.includesCustom)
    #expect(merged.custom.map(\.value) == ["premium"])
}

@Test func offerSignatureDecodes() throws {
    let signature = try decode(BotsiPromotionalSignatureDto.self, """
    {
      "keyId": "KEY123",
      "nonce": "6d92078a-8246-4ba4-ae5b-76104861e7dc",
      "timestamp": 1790000000000,
      "signature": "c2lnbmF0dXJl"
    }
    """)

    #expect(signature.timestamp == 1790000000000)
    #expect(Data(base64Encoded: signature.signature) == Data("signature".utf8))
}

@Test func apiErrorReadsCodeAndMessage() {
    let error = BotsiError.api(status: 404, data: Data(#"{"error":"Apple has no subscription","code":"nothing_to_restore"}"#.utf8))

    #expect(error.apiErrorCode == BotsiAPIErrorCode.nothingToRestore)
    #expect(!error.isRetryableAPIError)
    #expect(BotsiError.api(status: 503, data: Data()).isRetryableAPIError)
    #expect(BotsiError.api(status: 503, data: Data()).apiErrorCode == "http_503")
}

@Test func winBackOfferUsesTheAPICategory() throws {
    let offer = BotsiSubscriptionOffer(
        id: "winback-1",
        period: BotsiSubscriptionPeriod(unit: .month, numberOfUnits: 1),
        paymentMode: .payUpFront,
        offerType: .winBack,
        price: 4.99
    )
    let transaction = BotsiPaymentTransaction(
        transactionId: "1",
        originalTransactionId: "1",
        sourceProductId: "com.example.monthly",
        originalPrice: 9.99,
        priceLocale: "USD",
        storeCountry: "US",
        offer: offer,
        promotionalOfferId: "winback-1",
        discountPrice: "4.99",
        productId: "com.example.monthly",
        environment: "production",
        paywall: nil,
        isSubscription: true
    )
    
    let body = try jsonObject(BotsiValidateTransactionRequestDto(transaction: transaction, profileId: "p1", source: .purchasing))
    let sentOffer = try #require(body["offer"] as? [String: Any])
    
    // The API validates these against its OFFER_CATEGORY, IOS_OFFER_PERIOD and OFFER_TYPE enums.
    #expect(sentOffer["category"] as? String == "win_back")
    #expect(sentOffer["periodUnit"] as? String == "month")
    #expect(sentOffer["type"] as? String == "pay_up_front")
}

@Test func accessGrantedWithNullColumnsDecodes() throws {
    // Access granted from the dashboard leaves these nullable columns empty.
    let profile = try decode(BotsiProfile.self, """
    {
      "profileId": "p1",
      "appUserId": "user-1",
      "accessLevels": {
        "premium": {
          "createdDate": "2026-09-30T10:00:00.000Z",
          "id": 7,
          "isActive": true,
          "sourceProductId": null,
          "sourceBasePlanId": null,
          "store": null,
          "activatedAt": null,
          "isLifetime": null,
          "isRefund": null,
          "willRenew": null,
          "isInGracePeriod": null,
          "startsAt": null,
          "renewedAt": null,
          "expiresAt": null
        }
      },
      "subscriptions": {},
      "nonSubscriptions": {},
      "custom": []
    }
    """)
    
    let premium = try #require(profile.accessLevels["premium"])
    #expect(premium.isActive)
    #expect(premium.store == nil)
    #expect(premium.expiresAt == nil)
    #expect(!premium.isLifetime)
    
    let saved = try JSONDecoder().decode(BotsiProfile.self, from: JSONEncoder().encode(profile))
    #expect(saved.accessLevels["premium"]?.isActive == true)
}
