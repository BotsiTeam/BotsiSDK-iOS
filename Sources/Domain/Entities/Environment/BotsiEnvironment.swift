//
//  BotsiEnvironment.swift
//  Botsi
//
//  Created by Vladyslav on 23.02.2025.
//

import Foundation
import StoreKit

/// The device and app details a Botsi profile stores. `POST profiles` requires them, and the SDK
/// sends them again through `PATCH profiles/{profileId}` when an app or OS update changes them.
struct BotsiEnvironment: Codable, Equatable, Sendable {
    let country: String
    let device: String
    let os: String
    let platform: String
    let appVersion: String
    let appBuild: String?
    let locale: String?
    
    @BotsiActor
    static func current() async -> BotsiEnvironment {
        BotsiEnvironment(
            country: await StorefrontManager().countryCode(),
            device: Device.name,
            os: await BotsiSystemInfo.versionInfo,
            platform: await BotsiSystemInfo.systemName.lowercased(),
            appVersion: Application.version ?? "undefined",
            appBuild: Application.build,
            locale: SystemLocaleProvider().getUserLocale().languageCode
        )
    }
}

final class StorefrontManager {
    /// The App Store storefront's country (ISO alpha-3, such as `USA`), or the device region
    /// (alpha-2) when there is no storefront, as in the simulator.
    func countryCode() async -> String {
        if !BotsiEnvironment.Device.isSimulator, let storefront = await Storefront.current {
            BotsiLog.info("Storefront \(storefront.countryCode)")
            return storefront.countryCode
        }
        if let region = Locale.current.region?.identifier, region.count == 2, region.allSatisfy(\.isLetter) {
            return region
        }
        return "US"
    }
}


extension Botsi {
    public nonisolated static let sdkVersion = "2.0.0"
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
