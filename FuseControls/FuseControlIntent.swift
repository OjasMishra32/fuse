import AppIntents

/// Runs when the Control Center button is tapped: leaves a command for the app and opens it.
struct FuseControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Fuse"
    static let description = IntentDescription("Open Fuse and fuse what you were just doing.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        FuseCommandFlag.set("fuse")
        return .result()
    }
}
