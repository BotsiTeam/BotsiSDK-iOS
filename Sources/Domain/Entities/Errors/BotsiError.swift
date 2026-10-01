//
//  BotsiError.swift
//  Botsi
//
//  Created by Vladyslav on 20.02.2025.
//

import Foundation
import StoreKit

// MARK: - Botsi error protocol
protocol BotsiErrorConformable {
    var localizedDescription: String { get }
}

// MARK: - Botsi enum
public enum BotsiError: Error, Sendable, BotsiErrorConformable {
    case sdkNotActivated
    case sdkActivationKeyNotValid
    
    case userCreationFailed
    case userProfileNotFound
    case userGetProfileFailed
    
    case fetchingProductIdsFailed
    case paywallFetchingFailed
    
    case invalidProductIdentifier(String)
    case purchaseFailed(String)
    
    case unknownError(Error)
    case networkError(String)
    /// The Botsi API rejected the request. `code` is a stable slug, such as `not_found`; `message` may change.
    case apiError(status: Int, code: String, message: String)
    
    case transactionFailed
    case restoreFailed
    case transactionDeferred
    case promoOfferNotConfigured
    case paymentNotAllowed
    case userCancelled
    case receiptValidationFailed(String)
    
    case eventsError
    case asaTokenError
    
    case customError(String, String)

    public var localizedDescription: String {
        switch self {
        case .sdkActivationKeyNotValid:
            return "Incorrect activation key."
        case .userCreationFailed:
            return "User creation failed."
        case .userProfileNotFound:
            return "User profile not found."
        case .transactionFailed:
            return "Transaction failed."
        case .transactionDeferred:
            return "Transaction is deferred."
        case .promoOfferNotConfigured:
            return "Promotional offers aren't configured: the app's iOS settings in Botsi need a subscription key, bundle ID and issuer ID."
        case .invalidProductIdentifier(let identifier):
            return "Invalid product identifier: \(identifier)"
        case .purchaseFailed(let reason):
            return "Purchase failed: \(reason)"
        case .paymentNotAllowed:
            return "Payment is not allowed on this device."
        case .userCancelled:
            return "User cancelled the purchase."
        case .unknownError(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        case .networkError(let message):
            return "Network error: \(message)"
        case let .apiError(status, code, message):
            return "Botsi API error \(status) (\(code)): \(message)"
        case .receiptValidationFailed(let message):
            return "Receipt validation failed: \(message)"
        case .customError(let title, let message):
            return "Custom error: \(title) \(message)"
        case .sdkNotActivated:
            return "Unable to activate SDK"
        case .restoreFailed:
            return "Restore failed"
        case .fetchingProductIdsFailed:
            return "Fetching product ids failed"
        case .userGetProfileFailed:
            return "Request for user profile failed"
        case .paywallFetchingFailed:
            return "Request for fetching user's paywall with placement id failed"
        case .eventsError:
            return "Sending event analytics failed"
        case .asaTokenError:
            return "ASA token update error"
        }
    }
}

// MARK: - Botsi Error Builder
public struct BotsiErrorBuilder {
    private var title: String?
    private var message: String?
    
    public init() {}
    
    public func withTitle(_ title: String) -> BotsiErrorBuilder {
        var builder = self
        builder.title = title
        return builder
    }
    
    public func withMessage(_ message: String) -> BotsiErrorBuilder {
        var builder = self
        builder.message = message
        return builder
    }
    
    public func build() -> BotsiError {
        let errorTitle = title ?? "Error"
        let errorMessage = message ?? "An unexpected error occurred."
        return .customError(errorTitle, errorMessage)
    }
}

