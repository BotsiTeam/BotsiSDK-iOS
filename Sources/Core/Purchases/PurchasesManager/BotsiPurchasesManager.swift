//
//  BotsiPurchasesManager.swift
//  Botsi
//
//  Created by Vladyslav on 20.02.2025.
//

import StoreKit
import Foundation

protocol BotsiPurchasesManagerConformable: Sendable { }

extension BotsiPurchasesManagerConformable {
    
    func completeTransaction(
        with transaction: Transaction,
        product: Product,
        paywallId: Int?,
        abTestId: Int?,
        placementId: String? = nil
    ) async -> BotsiPaymentTransaction {
        return BotsiPaymentTransaction(
            with: product,
            transaction: transaction,
            paywallId: paywallId,
            abTestId: abTestId,
            placementId: placementId
        )
    }
}

struct BotsiStoreKit2TransactionMapper: BotsiPurchasesManagerConformable { }
