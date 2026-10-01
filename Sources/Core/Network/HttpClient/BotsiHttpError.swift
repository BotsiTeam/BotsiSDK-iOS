//
//  BotsiHttpError.swift
//  Botsi
//
//  Created by Vladyslav on 22.02.2025.
//

import Foundation

/// The `code` slugs of Botsi V2 API errors that the SDK acts on.
enum BotsiAPIErrorCode {
    static let notFound = "not_found"
    /// `POST purchases/apple-store/restore`: Apple has no subscription for the transaction.
    static let nothingToRestore = "nothing_to_restore"
    /// `POST offers/apple-store/promotional-signature`: the app's iOS settings can't sign offers.
    static let promoOfferNotConfigured = "promo_offer_not_configured"
}

extension BotsiError {
    /// Builds `apiError` from a V2 error reply, whose body is `{ "error": "<message>", "code": "<slug>" }`.
    static func api(status: Int, data: Data) -> BotsiError {
        let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
        return .apiError(
            status: status,
            code: body?.code ?? "http_\(status)",
            message: body?.error ?? HTTPURLResponse.localizedString(forStatusCode: status)
        )
    }

    /// The HTTP status of an `apiError`.
    var apiErrorStatus: Int? {
        guard case let .apiError(status, _, _) = self else { return nil }
        return status
    }
    
    /// The `code` of an `apiError`.
    var apiErrorCode: String? {
        guard case let .apiError(_, code, _) = self else { return nil }
        return code
    }

    /// Rate limiting and server faults can succeed on a later attempt.
    var isRetryableAPIError: Bool {
        guard case let .apiError(status, _, _) = self else { return false }
        return status == 429 || status >= 500
    }
}

private struct APIErrorBody: Decodable {
    let error: String?
    let code: String?
}
