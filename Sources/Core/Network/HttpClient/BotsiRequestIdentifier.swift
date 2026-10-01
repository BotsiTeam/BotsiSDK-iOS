//
//  BotsiRequestIdentifier.swift
//  Botsi
//
//  Created by Vladyslav on 22.02.2025.
//

// MARK: Route for endpoint
public struct BotsiRequestIdentifier: Sendable {
    static let activate: String = ""
    static let authenticate: String = ""
    static let logout: String = ""

    static let getProfile: String = ""
    static let createProfile: String = "profiles"
    static let updateProfile: String = ""
    
    static let getPaywall: String = "paywalls"
    static let events: String = "events"
   
    static let fetchProductIds: String = ""
    static let makePurchase: String = ""
    static let validateTransaction: String = "purchases/apple-store/validate"
    static let restorePurchases: String = "purchases/apple-store/restore"
    static let signPromotionalOffer: String = "offers/promo-sign/app_store"
    static let offerEligibility: String = "offers/intro-eligibility/app_store"
    
    static let asaToken: String = "attribution/asa"
}

public struct BotsiHTTPRequestPath: Sendable {
    let identifier: String
}
