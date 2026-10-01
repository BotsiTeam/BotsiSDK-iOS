import Testing
import Foundation
@testable import Botsi

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}

@Test func testDateParsing() async throws {
    let jsonString = """
    {
        "createdDate": "2025-07-19T08:26:46.000Z",
        "id": 1,
        "isActive": true,
        "sourceProductId": "test_product",
        "sourceBasePlanId": null,
        "store": "app_store",
        "activatedAt": "2025-07-19T08:26:46.000Z",
        "isLifetime": false,
        "isRefund": null,
        "willRenew": true,
        "isInGracePeriod": false,
        "cancellationReason": null,
        "offerId": null,
        "startsAt": "2025-07-19T08:26:46.000Z",
        "renewedAt": "2025-07-19T08:25:58.359Z",
        "expiresAt": "2025-07-19",
        "activeIntroductoryOfferType": null,
        "activePromotionalOfferType": null,
        "activePromotionalOfferId": null,
        "unsubscribedAt": null,
        "billingIssueDetectedAt": null
    }
    """
    
    let jsonData = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    
    let accessLevel = try decoder.decode(BotsiProfile.BotsiAccessLevel.self, from: jsonData)
    
    #expect((accessLevel.startsAt?.timeIntervalSince1970 ?? 0) > 0)
    #expect((accessLevel.renewedAt?.timeIntervalSince1970 ?? 0) > 0)
    #expect((accessLevel.expiresAt?.timeIntervalSince1970 ?? 0) > 0)
    
    let subscription = try decoder.decode(BotsiProfile.BotsiSubscription.self, from: jsonData)
    
    #expect((subscription.startsAt?.timeIntervalSince1970 ?? 0) > 0)
    #expect((subscription.renewedAt?.timeIntervalSince1970 ?? 0) > 0)
    #expect((subscription.expiresAt?.timeIntervalSince1970 ?? 0) > 0)
}

@Test func testProfileSavedBySDK1Decodes() async throws {
    // SDK 1.x saved profiles with `customerUserId` and `birthday`; 2.0 must still read them.
    let jsonString = """
    {
        "profileId": "test_profile_123",
        "customerUserId": "customer_456",
        "accessLevels": {},
        "subscriptions": {},
        "nonSubscriptions": {},
        "custom": [],
        "birthday": "2025-07-19T00:00:00.000Z"
    }
    """
    
    let profile = try JSONDecoder().decode(BotsiProfile.self, from: Data(jsonString.utf8))
    
    #expect(profile.profileId == "test_profile_123")
    #expect(profile.appUserId == "customer_456")
    #expect(profile.includesCustom)
    
    let saved = try JSONDecoder().decode(BotsiProfile.self, from: JSONEncoder().encode(profile))
    #expect(saved.appUserId == "customer_456")
}

@Test func testUnifiedDateUtils() async throws {
    let iso8601WithMillis = "2025-07-19T08:26:46.000Z"
    let iso8601WithoutMillis = "2025-07-19T08:26:46Z"
    let dateOnly = "2025-07-19"
    
    let date1 = try Date.parseISO8601(from: iso8601WithMillis)
    let date2 = try Date.parseISO8601(from: iso8601WithoutMillis)
    let date3 = try Date.parseISO8601(from: dateOnly)
    
    #expect(date1.timeIntervalSince1970 > 0)
    #expect(date2.timeIntervalSince1970 > 0)
    #expect(date3.timeIntervalSince1970 > 0)
    
    let testDate = Date(timeIntervalSince1970: 1721388000) // 2024-07-19 11:20:00 UTC
    
    let iso8601String = testDate.toISO8601String()
    let dateOnlyString = testDate.toISO8601DateString()
    
    #expect(iso8601String.contains("2024-07-19T11:20:00.000Z"))
    #expect(dateOnlyString == "2024-07-19")
    
    let parsedBack = try Date.parseISO8601(from: iso8601String)
    #expect(abs(parsedBack.timeIntervalSince1970 - testDate.timeIntervalSince1970) < 1)
}
