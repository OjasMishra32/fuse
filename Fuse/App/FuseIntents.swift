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

/// Fuse anywhere: a Shortcut does "Take Screenshot" → "Fuse Screenshot". Bind it to Back Tap or
/// the Action Button and any two apps open side by side on the phone can be fused.
struct FuseScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Fuse Screenshot"
    static let description = IntentDescription("Split a screenshot of the open phone along the fold and fuse the two apps on it. If no screenshot is passed, uses the newest one in Photos.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Screenshot", supportedContentTypes: [.image])
    var screenshot: IntentFile?

    static var parameterSummary: some ParameterSummary {
        Summary("Fuse \(\.$screenshot)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let file = screenshot {
            let data = (try? await file.data(contentType: .image)) ?? file.data
            if let name = SharedInbox.store(data: data, preferredName: "screen.png") {
                SharedInbox.enqueue(.init(side: .both, kind: .screen, title: "Screenshot", fileName: name))
            }
        }
        AppCommandBus.shared.send(.fuseScreenshot)
        return .result()
    }
}

// MARK: - Background fuse (native snippet, Fuse never comes to the front)

/// How the two apps were arranged in the capture, as a Shortcuts-visible enum.
enum FuseLayoutOption: String, AppEnum {
    case auto
    case leftRight
    case topBottom

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Layout"
    static let caseDisplayRepresentations: [FuseLayoutOption: DisplayRepresentation] = [
        .auto: "Automatic",
        .leftRight: "Left / Right",
        .topBottom: "Top / Bottom"
    ]

    var layout: FuseLayout {
        switch self {
        case .auto: .auto
        case .leftRight: .leftRight
        case .topBottom: .topBottom
        }
    }
}

/// "Take Screenshot" → (optional "Dictate Text") → "Fuse Screens". Runs in the background and
/// returns a native result card; the two source apps stay exactly where they were.
struct FuseScreensIntent: AppIntent {
    static let title: LocalizedStringResource = "Fuse Screens"
    static let description = IntentDescription("Fuse the two apps in a screenshot without opening Fuse. Pass the screenshot and, optionally, what you want done with it.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Screenshot", supportedContentTypes: [.image])
    var screenshot: IntentFile

    @Parameter(title: "Instruction")
    var instruction: String?

    @Parameter(title: "Layout", default: .auto)
    var layout: FuseLayoutOption

    static var parameterSummary: some ParameterSummary {
        Summary("Fuse \(\.$screenshot)") {
            \.$instruction
            \.$layout
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ShowsSnippetView {
        let data: Data
        if let loaded = try? await screenshot.data(contentType: .image), !loaded.isEmpty {
            data = loaded
        } else {
            data = screenshot.data
        }
        let image = try ScreenshotInput.decode(data)
        let result = try await BackgroundFuseService().run(image: image, instruction: instruction, layout: layout.layout)
        return .result(value: result.plainText, view: FuseSnippetView(result: result))
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
            intent: FuseScreenshotIntent(),
            phrases: ["Fuse my screen in \(.applicationName)", "\(.applicationName) what's on my screen"],
            shortTitle: "Fuse Screenshot",
            systemImageName: "rectangle.split.2x1"
        )
        AppShortcut(
            intent: FuseScreensIntent(),
            phrases: ["Fuse my screens in \(.applicationName)", "\(.applicationName) both apps on my screen"],
            shortTitle: "Fuse Screens",
            systemImageName: "rectangle.split.2x1.fill"
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
