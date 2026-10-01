//
//  BotsiPurchasesRepository.swift
//  Botsi
//

import Foundation

/// Purchase and offer calls on the Botsi V2 API.
struct BotsiPurchasesRepository {
    let httpClient: BotsiHttpClient

    /// Validates the transaction, attributed to its paywall through the paywall session when there is one.
    ///
    /// The API rejects a session it can't verify, such as one saved for renewals and signed with a key it has
    /// since retired. The purchase is then sent again with the explicit paywall fields so it's still recorded.
    func validateTransaction(
        _ transaction: BotsiPaymentTransaction,
        profileId: String,
        source: StoreKitTransactionSource
    ) async throws -> BotsiProfile {
        let path = "purchases/apple-store/validate"
        let body = BotsiValidateTransactionRequestDto(transaction: transaction, profileId: profileId, source: source)
        do {
            return try await httpClient.send(.post, path, body: body)
        } catch let error as BotsiError where body.paywallSessionId != nil && error.apiErrorStatus == 400 {
            BotsiLog.warn("Validate rejected the request with its paywall session; sending explicit paywall fields. \(error.localizedDescription)")
            let explicitBody = BotsiValidateTransactionRequestDto(
                transaction: transaction,
                profileId: profileId,
                source: source,
                useSession: false
            )
            return try await httpClient.send(.post, path, body: explicitBody)
        }
    }

    /// Restores the subscription that `originalTransactionId` belongs to onto the profile.
    ///
    /// - Throws: `BotsiError.apiError` with code `nothing_to_restore` when Apple has no subscription for it.
    func restore(profileId: String, originalTransactionId: String) async throws -> BotsiProfile {
        let body = BotsiRestoreRequestDto(profileId: profileId, originalTransactionId: originalTransactionId)
        return try await httpClient.send(.post, "purchases/apple-store/restore", body: body)
    }

    /// Signs a promotional offer so StoreKit will sell it.
    ///
    /// - Throws: `BotsiError.promoOfferNotConfigured` when the app's iOS settings can't sign offers.
    func promotionalSignature(profileId: String, productId: String, offerId: String) async throws -> BotsiPromotionalSignatureDto {
        let body = BotsiPromotionalSignatureRequestDto(profileId: profileId, productId: productId, offerId: offerId)
        do {
            return try await httpClient.send(.post, "offers/apple-store/promotional-signature", body: body)
        } catch let error as BotsiError where error.apiErrorCode == BotsiAPIErrorCode.promoOfferNotConfigured {
            throw BotsiError.promoOfferNotConfigured
        }
    }
}
