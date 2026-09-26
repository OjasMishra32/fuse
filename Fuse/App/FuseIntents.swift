import AppIntents
import SwiftUI

// MARK: - App Intents
//
// These make the fuse reachable from every physical input iOS offers besides the hinge:
// Back Tap (Settings › Accessibility › Touch › Back Tap → "Fuse"), the Action Button,
// Siri ("Fuse with voice"), the Shortcuts app and Spotlight.

struct FuseNowIntent: AppIntent {
    static let title: LocalizedStringResource = "Fuse"
    static let description = IntentDescription("Fuse whatever is on both screens.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppCommandBus.shared.send(.fuse)
        return .result()
    }
}

struct VoiceFuseIntent: AppIntent {
    static let title: LocalizedStringResource = "Fuse with Voice"
    static let description = IntentDescription("Start listening, then fuse both screens with what you said.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppCommandBus.shared.send(.listen)
        return .result()
    }
}

struct ClearFuseIntent: AppIntent {
    static let title: LocalizedStringResource = "Clear Fuse"
    static let description = IntentDescription("Clear both screens.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppCommandBus.shared.send(.reset)
        return .result()
    }
}

struct FuseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FuseNowIntent(),
            phrases: ["Fuse in \(.applicationName)", "\(.applicationName) both screens", "Run \(.applicationName)"],
            shortTitle: "Fuse",
            systemImageName: "circle.hexagongrid.fill"
        )
        AppShortcut(
            intent: VoiceFuseIntent(),
            phrases: ["Fuse with voice in \(.applicationName)", "Tell \(.applicationName) what to do"],
            shortTitle: "Fuse with Voice",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: ClearFuseIntent(),
            phrases: ["Clear \(.applicationName)"],
            shortTitle: "Clear",
            systemImageName: "xmark.circle"
        )
    }
}
