import Foundation

// MARK: - Keys & configuration
//
// Resolution order for every key: value pasted in Settings (UserDefaults) → Info.plist
// (filled from Config/Fuse.xcconfig / Secrets.local.xcconfig at build time) → empty.

enum AppConfig {
    enum Key: String, CaseIterable, Identifiable {
        case openAIKey, openAIModel, supabaseProjectRef, supabaseAnonKey, revenueCatKey

        var id: String { rawValue }

        var infoPlistKey: String {
            switch self {
            case .openAIKey: "OPENAI_API_KEY"
            case .openAIModel: "OPENAI_MODEL"
            case .supabaseProjectRef: "SUPABASE_PROJECT_REF"
            case .supabaseAnonKey: "SUPABASE_ANON_KEY"
            case .revenueCatKey: "REVENUECAT_API_KEY"
            }
        }

        var title: String {
            switch self {
            case .openAIKey: "OpenAI API key"
            case .openAIModel: "OpenAI model"
            case .supabaseProjectRef: "Supabase project ref"
            case .supabaseAnonKey: "Supabase anon key"
            case .revenueCatKey: "RevenueCat public key"
            }
        }

        var placeholder: String {
            switch self {
            case .openAIKey: "sk-…"
            case .openAIModel: "gpt-6-sol"
            case .supabaseProjectRef: "abcdefghijklmnop"
            case .supabaseAnonKey: "eyJ…"
            case .revenueCatKey: "appl_… or test_…"
            }
        }

        var isSecret: Bool {
            switch self {
            case .openAIModel, .supabaseProjectRef: false
            default: true
            }
        }

        var defaultsKey: String { "fuse.config.\(rawValue)" }
    }

    static func value(for key: Key) -> String {
        if let override = UserDefaults.standard.string(forKey: key.defaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return override
        }
        let plist = (Bundle.main.object(forInfoDictionaryKey: key.infoPlistKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return plist
    }

    static func set(_ value: String, for key: Key) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key.defaultsKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: key.defaultsKey)
        }
    }

    static var openAIKey: String { value(for: .openAIKey) }
    static var openAIModel: String {
        let m = value(for: .openAIModel)
        return m.isEmpty ? "gpt-6-sol" : m
    }
    static var supabaseProjectRef: String { value(for: .supabaseProjectRef) }
    static var supabaseAnonKey: String { value(for: .supabaseAnonKey) }
    static var supabaseURL: URL? {
        let ref = supabaseProjectRef
        guard !ref.isEmpty else { return nil }
        if ref.hasPrefix("http") { return URL(string: ref) }
        return URL(string: "https://\(ref).supabase.co")
    }
    static var revenueCatKey: String { value(for: .revenueCatKey) }

    static var hasOpenAI: Bool { !openAIKey.isEmpty }
    static var hasSupabase: Bool { supabaseURL != nil && !supabaseAnonKey.isEmpty }
    static var hasRevenueCat: Bool { !revenueCatKey.isEmpty }

    /// Posted whenever a key changes so services can reconfigure.
    static let didChange = Notification.Name("fuse.config.didChange")
}
