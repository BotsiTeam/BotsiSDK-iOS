Pod::Spec.new do |s|
    s.name             = "Botsi"
    s.version          = "2.0.0"
    s.summary          = "Botsi SDK for iOS."
    s.description      = "Seamless integration of in-app-purchases in your iOS application."
    s.homepage         = "https://www.botsi.com/"
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.authors          = { "Botsi, Inc." => "support@botsi.com" }
    s.source           = { :git => "https://github.com/BotsiTeam/BotsiSDK-iOS.git", :tag => s.version.to_s }
    s.documentation_url = "https://github.com/BotsiTeam/BotsiSDK-iOS/blob/main/botsi-documentation.md"

    s.ios.deployment_target = '16.0'
    s.swift_version = '5.9'

    s.source_files = 'Sources/**/*.swift'
    
    s.resources = ['Sources/PrivacyInfo.xcprivacy']
    
    s.frameworks = 'StoreKit'
end
