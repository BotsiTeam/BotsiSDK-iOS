//
//  LocaleProvider.swift
//  Botsi
//
//  Created by Vladyslav on 23.02.2025.
//

import Foundation

struct BotsiUserLocale {
    let languageCode: String
    let regionCode: String
    let currencyCode: String
    let identifier: String
}

protocol LocaleProviding {
    func getUserLocale() -> BotsiUserLocale
}

final class SystemLocaleProvider: LocaleProviding {
    func getUserLocale() -> BotsiUserLocale {
        let locale = Locale.current
        return BotsiUserLocale(
            languageCode: locale.language.languageCode?.identifier ?? "en",
            regionCode: locale.region?.identifier ?? "US",
            currencyCode: locale.currency?.identifier ?? "",
            identifier: locale.identifier
        )
    }
}

final class LocaleManager {
    private let provider: LocaleProviding
    
    init(provider: LocaleProviding = SystemLocaleProvider()) {
        self.provider = provider
    }
    
    func fetchUserLocale() -> BotsiUserLocale {
        return provider.getUserLocale()
    }
}
