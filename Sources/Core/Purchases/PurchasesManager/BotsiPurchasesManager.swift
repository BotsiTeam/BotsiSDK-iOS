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
        paywall: PaywallMeta?
    ) async -> BotsiPaymentTransaction {
        return BotsiPaymentTransaction(
            with: product,
            transaction: transaction,
            paywall: paywall
        )
    }
}

struct BotsiStoreKit2TransactionMapper: BotsiPurchasesManagerConformable { }
