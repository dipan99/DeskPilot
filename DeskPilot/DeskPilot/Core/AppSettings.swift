//
//  AppSettings.swift
//  DeskPilot
//

import Foundation

struct AppSettings: Equatable {
    let userName: String
    let userLocation: String
    let modelEndpoint: String
    let modelName: String
    let maxTokens: Int
    let conversationMemory: Int
    let responseStyle: ResponseStyle

    enum Keys {
        static let userName = "settings.userName"
        static let userLocation = "settings.userLocation"
        static let modelEndpoint = "settings.modelEndpoint"
        static let modelName = "settings.modelName"
        static let maxTokens = "settings.maxTokens"
        static let conversationMemory = "settings.conversationMemory"
        static let responseStyle = "settings.responseStyle"
    }

    enum Defaults {
        static let userName = ""
        static let userLocation = ""
        static let modelEndpoint = Constants.MLX.defaultBaseURL
        static let modelName = Constants.MLX.defaultModelName
        static let maxTokens = Constants.MLX.defaultMaxTokens
        static let conversationMemory = Constants.MLX.defaultConversationMemory
        static let responseStyle = ResponseStyle.concise.rawValue
    }

    enum ResponseStyle: String, CaseIterable, Identifiable {
        case concise
        case balanced
        case detailed

        var id: String { rawValue }

        var label: String {
            switch self {
            case .concise: return "Concise"
            case .balanced: return "Balanced"
            case .detailed: return "Detailed"
            }
        }

        var promptInstruction: String {
            switch self {
            case .concise:
                return "Keep responses concise and direct."
            case .balanced:
                return "Use a balanced amount of detail."
            case .detailed:
                return "Provide more detail when it helps the user act confidently."
            }
        }
    }

    static var current: AppSettings {
        let defaults = UserDefaults.standard
        let responseStyleRaw = defaults.string(forKey: Keys.responseStyle) ?? Defaults.responseStyle

        return AppSettings(
            userName: trimmedString(defaults.string(forKey: Keys.userName) ?? Defaults.userName),
            userLocation: trimmedString(defaults.string(forKey: Keys.userLocation) ?? Defaults.userLocation),
            modelEndpoint: sanitizedModelEndpoint(defaults.string(forKey: Keys.modelEndpoint) ?? Defaults.modelEndpoint),
            modelName: trimmedString(defaults.string(forKey: Keys.modelName) ?? Defaults.modelName).nilIfEmpty ?? Defaults.modelName,
            maxTokens: clampedInt(defaults.object(forKey: Keys.maxTokens) as? Int, defaultValue: Defaults.maxTokens, range: 256...8192),
            conversationMemory: clampedInt(defaults.object(forKey: Keys.conversationMemory) as? Int, defaultValue: Defaults.conversationMemory, range: 0...30),
            responseStyle: ResponseStyle(rawValue: responseStyleRaw) ?? .concise
        )
    }

    static func reset() {
        let defaults = UserDefaults.standard
        [
            Keys.userName,
            Keys.userLocation,
            Keys.modelEndpoint,
            Keys.modelName,
            Keys.maxTokens,
            Keys.conversationMemory,
            Keys.responseStyle
        ].forEach(defaults.removeObject(forKey:))
    }

    private static func trimmedString(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sanitizedModelEndpoint(_ value: String) -> String {
        trimmedString(value).nilIfEmpty ?? Defaults.modelEndpoint
    }

    private static func clampedInt(_ value: Int?, defaultValue: Int, range: ClosedRange<Int>) -> Int {
        min(max(value ?? defaultValue, range.lowerBound), range.upperBound)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
