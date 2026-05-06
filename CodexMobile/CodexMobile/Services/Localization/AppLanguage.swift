// FILE: AppLanguage.swift
// Purpose: Stores the user-selected app language and provides localized demo/settings copy.
// Layer: Service
// Exports: AppLanguage, AppLanguageText
// Depends on: Foundation

import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case english = "en"
    case chinese = "zh-Hans"

    static let storageKey = "codex.appLanguage"
    static let defaultLanguage: AppLanguage = .english

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }

    static func stored(in defaults: UserDefaults = .standard) -> AppLanguage {
        guard let rawValue = defaults.string(forKey: storageKey),
              let language = AppLanguage(rawValue: rawValue) else {
            return defaultLanguage
        }

        return language
    }

    func store(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }
}

enum AppLanguageText {
    static func localized(_ key: String, for language: AppLanguage, bundle: Bundle = .main) -> String {
        guard language != .english,
              let path = bundle.path(forResource: language.rawValue, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return key
        }

        return languageBundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func settingsTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Settings"
        case .chinese:
            return "设置"
        }
    }

    static func languageCardTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Language"
        case .chinese:
            return "语言"
        }
    }

    static func languagePickerTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Language"
        case .chinese:
            return "语言"
        }
    }

    static func languageFootnote(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Applies immediately to the demo UI. Backend and core service code stays unchanged."
        case .chinese:
            return "会立即应用到演示 UI。后端和核心服务代码保持不变。"
        }
    }

    static func demoAccessTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Demo Access"
        case .chinese:
            return "演示访问"
        }
    }

    static func proAccessTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Remodex Pro"
        case .chinese:
            return "Remodex Pro"
        }
    }

    static func statusLabel(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Status"
        case .chinese:
            return "状态"
        }
    }

    static func demoStatusLabel(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Demo"
        case .chinese:
            return "演示"
        }
    }

    static func demoAccessDescription(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "RevenueCat and purchase flows are retained in the project, but this open-source build runs with local demo access."
        case .chinese:
            return "RevenueCat 和购买流程仍保留在项目中，但这个开源版本使用本地演示访问。"
        }
    }

    static func howCodexAppWorksTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "How codex app Works"
        case .chinese:
            return "codex app 工作方式"
        }
    }
}
