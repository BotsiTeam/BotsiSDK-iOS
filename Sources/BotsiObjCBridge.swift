//
//  BotsiObjCBridge.swift
//  Botsi
//
//  Created by Vladyslav on 19.02.2025.
//

import Foundation

@objc(BotsiObjCGender)
public enum BotsiObjCGender: Int {
    case male = 0
    case female = 1
    case other = 2
    case preferNotSay = 3
    
    init(swift: BotsiGender) {
        switch swift {
        case .male:
            self = .male
        case .female:
            self = .female
        case .other:
            self = .other
        case .preferNotSay:
            self = .preferNotSay
        }
    }
    
    var swift: BotsiGender {
        switch self {
        case .male:
            return .male
        case .female:
            return .female
        case .other:
            return .other
        case .preferNotSay:
            return .preferNotSay
        }
    }
}

@objc(BotsiObjCCustomEntry)
public class BotsiObjCCustomEntry: NSObject {
    @objc public let key: String
    @objc public let value: String
    @objc public let id: String
    
    @objc public init(key: String, value: String, id: String) {
        self.key = key
        self.value = value
        self.id = id
        super.init()
    }
    
    convenience init(swift: BotsiProfile.BotsiCustomEntry) {
        self.init(key: swift.key, value: swift.value, id: swift.id)
    }
    
    var swift: BotsiProfile.BotsiCustomEntry {
        return BotsiProfile.BotsiCustomEntry(key: key, value: value, id: id)
    }
}

@objc(BotsiObjCUserProfileInformation)
public class BotsiObjCUserProfileInformation: NSObject {
    @objc public let birthday: Date?
    @objc public let email: String?
    @objc public let username: String?
    @objc public let gender: BotsiObjCGender
    @objc public let phone: String?
    @objc public let custom: [BotsiObjCCustomEntry]?
    @objc public let idfa: String?
    @objc public let advertisingId: String?
    
    @objc public init(birthday: Date?, email: String?, username: String?, gender: BotsiObjCGender, phone: String?, custom: [BotsiObjCCustomEntry]?, idfa: String?, advertisingId: String?) {
        self.birthday = birthday
        self.email = email
        self.username = username
        self.gender = gender
        self.phone = phone
        self.custom = custom
        self.idfa = idfa
        self.advertisingId = advertisingId
        super.init()
    }
    
    convenience init(swift: BotsiUserProfileInformation) {
        let objcGender = BotsiObjCGender(swift: swift.gender ?? .preferNotSay)
        let objcCustom = swift.custom?.map { BotsiObjCCustomEntry(swift: $0) }
        self.init(birthday: swift.birthday,
                  email: swift.email,
                  username: swift.username,
                  gender: objcGender,
                  phone: swift.phone,
                  custom: objcCustom,
                  idfa: swift.idfa,
                  advertisingId: swift.advertisingId)
    }
    
    var swift: BotsiUserProfileInformation {
        return BotsiUserProfileInformation(
            birthday: birthday,
            email: email,
            username: username,
            gender: gender.swift,
            phone: phone,
            custom: custom?.map { $0.swift },
            idfa: idfa,
            advertisingId: advertisingId
        )
    }
}

@objc(BotsiObjCProfile)
public class BotsiObjCProfile: NSObject {
    @objc public let profileId: String
    @objc public let appUserId: String?
    @objc public let accessLevels: [String: Any]
    @objc public let subscriptions: [String: Any]
    @objc public let nonSubscriptions: [String: Any]
    @objc public let custom: [Any]
    
    // Store the original Swift profile for conversion back
    let swiftProfile: BotsiProfile
    
    public init(profileId: String, appUserId: String?, accessLevels: [String: Any], subscriptions: [String: Any], nonSubscriptions: [String: Any], custom: [Any], swiftProfile: BotsiProfile) {
        self.profileId = profileId
        self.appUserId = appUserId
        self.accessLevels = accessLevels
        self.subscriptions = subscriptions
        self.nonSubscriptions = nonSubscriptions
        self.custom = custom
        self.swiftProfile = swiftProfile
        super.init()
    }
    
    convenience init(swift: BotsiProfile) {
        // Convert Swift types to Objective-C compatible types
        let accessLevelsDict = swift.accessLevels.mapValues { $0 as Any }
        let subscriptionsDict = swift.subscriptions.mapValues { $0 as Any }
        let nonSubscriptionsDict = swift.nonSubscriptions.mapValues { $0 as Any }
        let customArray = swift.custom.map { $0 as Any }
        
        self.init(profileId: swift.profileId,
                  appUserId: swift.appUserId,
                  accessLevels: accessLevelsDict,
                  subscriptions: subscriptionsDict,
                  nonSubscriptions: nonSubscriptionsDict,
                  custom: customArray,
                  swiftProfile: swift)
    }
    
    public static func fromSwift(swift: BotsiProfile) -> BotsiObjCProfile {
        // Convert Swift types to Objective-C compatible types
        let accessLevelsDict = swift.accessLevels.mapValues { $0 as Any }
        let subscriptionsDict = swift.subscriptions.mapValues { $0 as Any }
        let nonSubscriptionsDict = swift.nonSubscriptions.mapValues { $0 as Any }
        let customArray = swift.custom.map { $0 as Any }
        
        return BotsiObjCProfile(profileId: swift.profileId,
                  appUserId: swift.appUserId,
                  accessLevels: accessLevelsDict,
                  subscriptions: subscriptionsDict,
                  nonSubscriptions: nonSubscriptionsDict,
                  custom: customArray,
                  swiftProfile: swift)
    }
    
    /// Convert Objective-C profile back to Swift profile
    public func toSwift() -> BotsiProfile {
        return swiftProfile
    }
}

@objc(BotsiObjCProduct)
public class BotsiObjCProduct: NSObject {
    @objc public let productId: String
    @objc public let title: String
    @objc public let descriptionText: String
    @objc public let price: NSDecimalNumber
    @objc public let currencyCode: String?
    @objc public let localizedPrice: String?
    @objc public let introductoryPrice: String?
    @objc public let subscriptionGroupIdentifier: String?
    @objc public let localizedSubscriptionPeriod: String?
    @objc public let isEligibleForIntroOffer: Bool
    
    let swiftProduct: BotsiProduct
    
    public init(productId: String, title: String, descriptionText: String, price: NSDecimalNumber, currencyCode: String?, localizedPrice: String?, introductoryPrice: String?, subscriptionGroupIdentifier: String?, localizedSubscriptionPeriod: String?, isEligibleForIntroOffer: Bool, swiftProduct: BotsiProduct) {
        self.productId = productId
        self.title = title
        self.descriptionText = descriptionText
        self.price = price
        self.currencyCode = currencyCode
        self.localizedPrice = localizedPrice
        self.introductoryPrice = introductoryPrice
        self.subscriptionGroupIdentifier = subscriptionGroupIdentifier
        self.localizedSubscriptionPeriod = localizedSubscriptionPeriod
        self.isEligibleForIntroOffer = isEligibleForIntroOffer
        self.swiftProduct = swiftProduct
        super.init()
    }
    
    convenience init(swift: BotsiProduct) {
        self.init(productId: swift.productId,
                  title: swift.title,
                  descriptionText: swift.descriptionText,
                  price: NSDecimalNumber(decimal: swift.price),
                  currencyCode: swift.currencyCode,
                  localizedPrice: swift.localizedPrice,
                  introductoryPrice: swift.introductoryPrice,
                  subscriptionGroupIdentifier: swift.subscriptionGroupIdentifier,
                  localizedSubscriptionPeriod: swift.localizedSubscriptionPeriod,
                  isEligibleForIntroOffer: swift.isEligibleForIntroOffer,
                  swiftProduct: swift)
    }
    
    public static func fromSwift(swift: BotsiProduct) -> BotsiObjCProduct {
        return BotsiObjCProduct(productId: swift.productId,
                  title: swift.title,
                  descriptionText: swift.descriptionText,
                  price: NSDecimalNumber(decimal: swift.price),
                  currencyCode: swift.currencyCode,
                  localizedPrice: swift.localizedPrice,
                  introductoryPrice: swift.introductoryPrice,
                  subscriptionGroupIdentifier: swift.subscriptionGroupIdentifier,
                  localizedSubscriptionPeriod: swift.localizedSubscriptionPeriod,
                  isEligibleForIntroOffer: swift.isEligibleForIntroOffer,
                  swiftProduct: swift)
    }
    
    /// Convert Objective-C product back to Swift product
    public func toSwift() -> BotsiProduct {
        return swiftProduct
    }
}

@objc(BotsiObjCPaywall)
public class BotsiObjCPaywall: NSObject {
    @objc public let placementId: String
    @objc public let paywallId: Int
    @objc public let externalId: String?
    @objc public let name: String
    @objc public let isExperiment: Bool
    /// The AI pricing model that chose the paywall, or `nil`.
    @objc public let aiPricingModelId: NSNumber?
    @objc public let paywallSessionId: String
    
    public let swiftPaywall: BotsiPaywall
    
    public init(swiftPaywall: BotsiPaywall) {
        self.placementId = swiftPaywall.placementId
        self.paywallId = swiftPaywall.id
        self.externalId = swiftPaywall.externalId
        self.name = swiftPaywall.name
        self.isExperiment = swiftPaywall.isExperiment
        self.aiPricingModelId = swiftPaywall.aiPricingModelId.map { NSNumber(value: $0) }
        self.paywallSessionId = swiftPaywall.paywallSessionId
        self.swiftPaywall = swiftPaywall
        super.init()
    }
    
    convenience init(swift: BotsiPaywall) {
        self.init(swiftPaywall: swift)
    }
}

@objc(BotsiObjCError)
public class BotsiObjCError: NSObject {
    @objc public let localizedDescription: String
    @objc public let errorCode: String
    
    // Store the original error for conversion back
    let error: Error
    
    public init(localizedDescription: String, errorCode: String, error: Error) {
        self.localizedDescription = localizedDescription
        self.errorCode = errorCode
        self.error = error
        super.init()
    }
    
    convenience init(swift: Error) {
        let nsError = swift as NSError
        self.init(localizedDescription: nsError.localizedDescription, errorCode: "\(nsError.domain)-\(nsError.code)", error: swift)
    }
    
    convenience init(_ error: Error) {
        let nsError = error as NSError
        self.init(localizedDescription: nsError.localizedDescription, errorCode: "\(nsError.domain)-\(nsError.code)", error: error)
    }
    
    public static func fromSwift(swift: Error) -> BotsiObjCError {
        let nsError = swift as NSError
        return BotsiObjCError(localizedDescription: nsError.localizedDescription, errorCode: "\(nsError.domain)-\(nsError.code)", error: swift)
    }
    
    /// Convert Objective-C error back to Swift error
    public func toSwift() -> Error {
        return error
    }
}

@objc(BotsiObjCSDK)
public class BotsiObjCSDK: NSObject {
    @objc public static func activate(_ key: String, completion: @escaping @Sendable (BotsiObjCError?) -> Void) {
        Task {
            do {
                try await Botsi.activate(key)
                completion(nil)
            } catch {
                completion(BotsiObjCError(swift: error))
            }
        }
    }
    
    @objc public static func activate(_ key: String, appUserId: String?, completion: @escaping @Sendable (BotsiObjCError?) -> Void) {
        Task {
            do {
                try await Botsi.activate(key, appUserId: appUserId)
                completion(nil)
            } catch {
                completion(BotsiObjCError(swift: error))
            }
        }
    }
    
    @objc public static func getProfile(completion: @escaping @Sendable (BotsiObjCProfile?, BotsiObjCError?) -> Void) {
        Task {
            do {
                let profile = try await Botsi.getProfile()
                completion(BotsiObjCProfile(swift: profile), nil)
            } catch {
                completion(nil, BotsiObjCError(swift: error))
            }
        }
    }
    
    @objc public static func updateProfile(_ profileUpdate: BotsiObjCUserProfileInformation, completion: @escaping @Sendable (BotsiObjCProfile?, BotsiObjCError?) -> Void) {
        let swiftProfileUpdate = profileUpdate.swift
        Task {
            do {
                let updatedProfile = try await Botsi.updateProfile(swiftProfileUpdate)
                completion(BotsiObjCProfile(swift: updatedProfile), nil)
            } catch {
                completion(nil, BotsiObjCError(swift: error))
            }
        }
    }
    
    @objc public static func getPaywall(from placementId: String, completion: @escaping @Sendable (BotsiObjCPaywall?, BotsiObjCError?) -> Void) {
        Task {
            do {
                let paywall = try await Botsi.getPaywall(from: placementId)
                completion(BotsiObjCPaywall(swift: paywall), nil)
            } catch {
                completion(nil, BotsiObjCError(swift: error))
            }
        }
    }
    
    @objc public static func getPaywallProducts(from paywall: BotsiObjCPaywall, completion: @escaping @Sendable ([BotsiObjCProduct]?, BotsiObjCError?) -> Void) {
        let swiftPaywall = paywall.swiftPaywall
        Task {
            do {
                let products = try await Botsi.getPaywallProducts(from: swiftPaywall)
                let objcProducts = products.map { BotsiObjCProduct(swift: $0) }
                completion(objcProducts, nil)
            } catch {
                completion(nil, BotsiObjCError(swift: error))
            }
        }
    }
    
    @objc public static func makePurchase(_ product: BotsiObjCProduct, completion: @escaping @Sendable (BotsiObjCProfile?, BotsiObjCError?) -> Void) {
        let swiftProduct = product.swiftProduct
        Task {
            do {
                let updatedProfile = try await Botsi.makePurchase(swiftProduct)
                completion(BotsiObjCProfile(swift: updatedProfile), nil)
            } catch {
                completion(nil, BotsiObjCError(swift: error))
            }
        }
    }
    
    @objc public static func identify(_ userId: String, completion: @escaping @Sendable (BotsiObjCError?) -> Void) {
        Task {
            do {
                try await Botsi.identify(userId)
                completion(nil)
            } catch {
                completion(BotsiObjCError(swift: error))
            }
        }
    }
    
    @objc public static func logout(completion: @escaping @Sendable (BotsiObjCError?) -> Void) {
        Task {
            do {
                try await Botsi.logout()
                completion(nil)
            } catch {
                completion(BotsiObjCError(swift: error))
            }
        }
    }
    
    @objc public static func restorePurchases(completion: @escaping @Sendable (BotsiObjCProfile?, BotsiObjCError?) -> Void) {
        Task {
            do {
                let profile = try await Botsi.restorePurchases()
                completion(BotsiObjCProfile(swift: profile), nil)
            } catch {
                completion(nil, BotsiObjCError(swift: error))
            }
        }
    }
    
    @objc public static func logPaywallShown(_ paywall: BotsiObjCPaywall, completion: @escaping @Sendable (BotsiObjCError?) -> Void) {
        let swiftPaywall = paywall.swiftPaywall
        Task {
            do {
                try await Botsi.logPaywallShown(for: swiftPaywall)
                completion(nil)
            } catch {
                completion(BotsiObjCError(swift: error))
            }
        }
    }
    
    @objc public static func updateRefundDataConsent(_ consent: Bool, completion: @escaping @Sendable (BotsiObjCError?) -> Void) {
        Task {
            do {
                try await Botsi.updateRefundDataConsent(consent)
                completion(nil)
            } catch {
                completion(BotsiObjCError(swift: error))
            }
        }
    }
} 
