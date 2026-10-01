//
//  BotsiEnvironment.swift
//  Botsi
//
//  Created by Vladyslav on 23.02.2025.
//

import Foundation
import StoreKit

@BotsiActor
final class BotsiEnvironment: Sendable {
    let storeCountry: String
    let botsiSdkVersion: String
    let advertisingId: String
    let androidId: String
    let appBuild: String
    let androidAppSetId: String
    let appVersion: String
    let device: String
    let deviceId: String
    let locale: String
    let os: String
    let platform: String
    let timezone: String
    
    init() async throws {
        self.storeCountry = try await StorefrontManager().getStorefront().countryCode
        self.botsiSdkVersion = Botsi.sdkVersion
        self.advertisingId = UUID().uuidString
        self.androidId = UUID().uuidString
        self.appBuild = Application.build ?? "undefined"
        self.androidAppSetId = UUID().uuidString
        self.appVersion = Application.version ?? "undefined"
        self.device = Device.name
        self.deviceId = await Device.getIdentifierForVendor()
        self.locale = SystemLocaleProvider().getUserLocale().languageCode
        self.os = await BotsiSystemInfo.versionInfo
        self.platform = await BotsiSystemInfo.systemName.lowercased()
        self.timezone = TimeZone.current.identifier
    }
}

struct BotsiStorefront {
    let id: String
    let countryCode: String
}

protocol StorefrontProvider {
    func fetchStorefront() async throws -> BotsiStorefront
}

final class StoreKitSimulatorMockProvider: StorefrontProvider {
    func fetchStorefront() async throws -> BotsiStorefront {
        return .init(id: UUID().uuidString, countryCode: "en")
    }
}

final class StoreKit2Provider: StorefrontProvider {
    func fetchStorefront() async throws -> BotsiStorefront {
        let storefront = await Storefront.current
        if let storefront {
            BotsiLog.info("Storefront \(storefront.countryCode)")
        }
        return BotsiStorefront(id: storefront?.id ?? "unknown", countryCode: storefront?.countryCode ?? "default")
    }
}

final class StorefrontManager {
    
    private let provider: StorefrontProvider
    
    init() {
        if BotsiEnvironment.Device.isSimulator {
            self.provider = StoreKitSimulatorMockProvider()
        } else {
            self.provider = StoreKit2Provider()
        }
    }
    
    func getStorefront() async throws -> BotsiStorefront {
        return try await provider.fetchStorefront()
    }
}

enum StorefrontError: Error {
    case storefrontUnavailable
    case unknownError
}


extension Botsi {
    public nonisolated static let sdkVersion = "1.0"
}

extension BotsiEnvironment {
    enum Device {
        #if targetEnvironment(simulator)
            static let isSimulator = true
        #else
            static let isSimulator = false
        #endif

        static let name: String = {
            #if os(macOS) || targetEnvironment(macCatalyst)
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))

                var modelIdentifier: String?
                if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
                    modelIdentifier = String(data: modelData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
                }
                IOObjectRelease(service)

                if modelIdentifier?.isEmpty ?? false {
                    modelIdentifier = nil
                }

                return modelIdentifier ?? "unknown device"

            #else
                var systemInfo = utsname()
                uname(&systemInfo)
                let machineMirror = Mirror(reflecting: systemInfo.machine)
                return machineMirror.children.reduce("") { identifier, element in
                    guard let value = element.value as? Int8, value != 0 else { return identifier }
                    return identifier + String(UnicodeScalar(UInt8(value)))
                }
            #endif
        }()
        
        static func getIdentifierForVendor() async -> String {
            await MainActor.run {
                #if os(iOS) || os(tvOS) || os(visionOS)
                return UIDevice.current.identifierForVendor?.uuidString ?? "idfv undefined"
                #elseif os(watchOS)
                return WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "idfv undefined"
                #else
                return "Unsupported OS"
                #endif
            }
        }
    }
}

extension BotsiEnvironment {
    enum Application {
        static let version: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        static let build: String? = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }
}

@BotsiActor
struct BotsiSystemInfo {
    
    private static var `version`: String?
    
    static var versionInfo: String {
        get async {
            if let result = version { return result }

            #if os(macOS) || targetEnvironment(macCatalyst)
                let result = await MainActor.run { ProcessInfo().operatingSystemVersionString }
            #else
                let result = await UIDevice.current.systemVersion
            #endif

            version = result
            return result
        }
    }
    
    private static var `name`: String?

    static var systemName: String {
        get async {
            if let result = name { return result }

            #if os(macOS) || targetEnvironment(macCatalyst)
                let result = "macOS"
            #else
                let result = await UIDevice.current.systemName
            #endif

            name = result
            return result
        }
    }
}
