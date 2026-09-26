import Foundation
import UIKit

// MARK: - Background fuse
//
// The execution path behind the "Fuse Screens" App Intent. It runs without any scene, pane,
// command bus or URL navigation: validate the explicit screenshot → crop → existing
// `FuseEngine` with screenshot framing → restrict the artifact to text → persist → record
// usage once. Results stay local (no Supabase upload on this route).

struct BackgroundFuseService {
    enum ServiceError: LocalizedError, Equatable {
        case missingOpenAIKey
        case quotaExceeded
        case cancelled

        var errorDescription: String? {
            switch self {
            case .missingOpenAIKey: return "Add your OpenAI key in Fuse › Settings first."
            case .quotaExceeded: return "You've used today's free fuses. Upgrade in Fuse to keep going."
            case .cancelled: return "Fuse was cancelled."
            }
        }
    }

    /// The engine boundary: (left, right, instruction) → result. Injected so tests never touch the network.
    typealias Engine = (SurfaceSnapshot, SurfaceSnapshot, String?) async throws -> FuseResult

    /// Side effects that happen exactly once per successful invocation.
    typealias SuccessHook = (FuseResult) async -> Void

    var store: FuseJobStore
    var engine: Engine
    /// Whether to require an OpenAI key and free-tier quota before running (off in unit tests).
    var enforcesConfiguration: Bool
    var onSuccess: SuccessHook

    init(
        store: FuseJobStore = .shared,
        engine: Engine? = nil,
        enforcesConfiguration: Bool = true,
        onSuccess: SuccessHook? = nil
    ) {
        self.store = store
        self.engine = engine ?? Self.liveEngine
        self.enforcesConfiguration = enforcesConfiguration
        self.onSuccess = onSuccess ?? Self.liveSuccessHook
    }

    // MARK: Run

    /// Validate, crop, fuse and persist. Throws a `LocalizedError` the Shortcut can show.
    func run(image: UIImage, instruction: String?, layout: FuseLayout) async throws -> FuseResult {
        let trimmed = instruction?.trimmingCharacters(in: .whitespacesAndNewlines)
        let spoken = (trimmed?.isEmpty == false) ? trimmed : nil

        // 1. The explicit image is authoritative: any failure here is an error, never a fallback.
        let (left, right, _) = try ScreenshotInput.snapshots(from: image, layout: layout)

        // 2. Usage checks: surface as errors, never as Settings/paywall navigation.
        if enforcesConfiguration {
            guard AppConfig.hasOpenAI else { throw ServiceError.missingOpenAIKey }
            let allowed = await MainActor.run { RevenueCatService.shared.canFuse }
            guard allowed else { throw ServiceError.quotaExceeded }
        }

        // 3. One job per invocation.
        let job = try await store.create(instruction: spoken, layout: layout)
        try await store.update(id: job.id) { $0.state = .running }
        await store.cleanup()

        do {
            try Task.checkCancellation()
            var result = try await engine(left, right, spoken)
            try Task.checkCancellation()

            result = Self.restrictArtifact(result)
            result.instruction = spoken
            if result.inputs.isEmpty {
                result.inputs = [InputSummary(kind: .photo, title: left.title), InputSummary(kind: .photo, title: right.title)]
            }

            // 4. Persist before presenting; complete exactly once.
            let first = try await store.complete(id: job.id, result: result)
            if first {
                await onSuccess(result)
            }
            return result
        } catch is CancellationError {
            _ = try? await store.fail(id: job.id, error: ServiceError.cancelled.localizedDescription)
            throw ServiceError.cancelled
        } catch {
            _ = try? await store.fail(id: job.id, error: error.localizedDescription)
            throw error
        }
    }

    // MARK: Artifact restriction

    /// The background text-demo route never issues the second image API request: an `.image`
    /// artifact becomes markdown of the summary (or the router's caption/prompt when the summary is empty).
    static func restrictArtifact(_ result: FuseResult) -> FuseResult {
        guard case .image(let image) = result.artifact else { return result }
        var copy = result
        let summary = result.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = (image.caption ?? image.prompt).trimmingCharacters(in: .whitespacesAndNewlines)
        copy.artifact = .markdown(summary.isEmpty ? fallback : summary)
        return copy
    }

    // MARK: Live wiring

    private static let liveEngine: Engine = { left, right, instruction in
        try await FuseEngine().fuse(
            left: left,
            right: right,
            instruction: instruction,
            suggested: nil,
            framing: Prompts.screenshotFraming,
            progress: { _ in }
        )
    }

    private static let liveSuccessHook: SuccessHook = { result in
        await MainActor.run {
            HistoryStore.shared.add(result)
            RevenueCatService.shared.recordFuse()
        }
    }
}
