import SwiftUI
import Observation

// MARK: - AppModel
//
// The single state machine. Two panes, one hinge, one phase.
//
//   compose ──(fold / hold seam / pinch / voice / intent)──▶ fusing ──▶ result ──(reopen / close)──▶ compose
//
// Fold progress (0 = flat, 1 = closed) is what the melt animation reads. It comes from the
// real hinge angle, or from a pinch gesture, or from the seam hold ramp, or from the debug slider.

enum FuseTrigger: String {
    case fold, pinch, seam, voice, intent, demo, followUp
}

@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case compose
        case fusing
        case result
        case failed(String)
    }

    // Panes
    let left = Pane(side: .left, kind: .web)
    let right = Pane(side: .right, kind: .maps)

    // Hinge
    var hinge: DeviceHinge?
    var hingeAvailable: Bool { hinge != nil }
    var isClosed: Bool { hinge?.status == .closed }
    var hingeDegrees: Double { hinge?.angle.degrees ?? 180 }

    /// 0 = open, 1 = fully folded. Whatever is driving the melt right now.
    var foldProgress: Double = 0
    /// Set by the hidden dev panel to rehearse the melt without the hinge.
    var debugFold: Double? = nil
    var showDevPanel = false

    // Flow
    var phase: Phase = .compose
    var instruction: String = ""
    var currentResult: FuseResult?
    var fusingStage: String = ""
    var fusingStartedAt: Date?
    var lastTrigger: FuseTrigger?
    var hint: String?

    // Sheets
    var showSettings = false
    var showHistory = false
    var showCommunity = false
    var showPaywall = false
    var showInstructionEditor = false

    // Intent preview: what the model thinks the fold should do, right now.
    var suggestions: [FuseSuggestion] = []
    var chosenSuggestion: FuseSuggestion?
    var isPreviewing = false
    private var previewTask: Task<Void, Never>?
    private var lastPreviewKey = ""

    private var fuseTask: Task<Void, Never>?
    private var armed = true
    private var hintTask: Task<Void, Never>?

    var readiness: Int { (left.model.hasContent ? 1 : 0) + (right.model.hasContent ? 1 : 0) }
    var isReady: Bool { readiness >= 1 }
    var isFusing: Bool { phase == .fusing }

    /// Changes whenever the live content of either screen changes. Drives the intent preview.
    var contentKey: String {
        "\(left.kind.rawValue)|\(left.model.hasContent)|\(left.model.headline)|\(right.kind.rawValue)|\(right.model.hasContent)|\(right.model.headline)"
    }

    /// What the fold will do if the user doesn't say otherwise.
    var defaultSuggestion: FuseSuggestion? { chosenSuggestion ?? suggestions.first }

    // MARK: Intent preview

    func schedulePreview() {
        let key = contentKey
        guard key != lastPreviewKey else { return }
        lastPreviewKey = key
        previewTask?.cancel()
        chosenSuggestion = nil
        guard readiness > 0, AppConfig.hasOpenAI else {
            withAnimation(Theme.snappy) { suggestions = []; isPreviewing = false }
            return
        }
        previewTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, self.phase == .compose else { return }
            withAnimation(Theme.snappy) { self.isPreviewing = true }
            async let l = self.left.model.capture()
            async let r = self.right.model.capture()
            let (ls, rs) = await (l, r)
            guard !Task.isCancelled else { return }
            let found = (try? await IntentPreviewer().suggest(left: ls, right: rs)) ?? []
            guard !Task.isCancelled else { return }
            withAnimation(Theme.smooth) {
                self.suggestions = found
                self.isPreviewing = false
            }
            if !found.isEmpty { Haptics.soft() }
        }
    }

    func choose(_ suggestion: FuseSuggestion) {
        Haptics.selection()
        withAnimation(Theme.snappy) {
            chosenSuggestion = suggestion
            instruction = suggestion.instruction
        }
    }

    // MARK: Hinge

    func handleHinge(old: DeviceHingeContext, new: DeviceHingeContext) {
        hinge = new.hinge
        guard let h = new.hinge else { return }
        let deg = h.angle.degrees

        if debugFold == nil {
            // Start melting once the user commits to a fold, finish just before closed.
            let p = ((165 - deg) / 135).clamped(to: 0...1)
            withAnimation(Theme.melt) { foldProgress = p }
        }

        // Re-arm once reopened.
        if deg > 120 { armed = true }

        let justClosed = h.status == .closed && old.hinge?.status != .closed
        if (justClosed || (deg < 22 && h.status != .fullyOpen)) && armed && phase == .compose {
            armed = false
            fuse(trigger: .fold)
        }
    }

    // MARK: Triggers

    /// Pinch the two halves together: progress from the gesture's scale.
    func setPinch(progress: Double, ended: Bool) {
        guard phase == .compose, debugFold == nil else { return }
        if ended {
            if progress >= 1 {
                fuse(trigger: .pinch)
            } else {
                withAnimation(Theme.smooth) { foldProgress = 0 }
            }
        } else {
            foldProgress = progress.clamped(to: 0...1)
            if progress >= 1 { fuse(trigger: .pinch) }
        }
    }

    func setDebugFold(_ value: Double?) {
        debugFold = value
        if let value {
            withAnimation(Theme.melt) { foldProgress = value }
            if value >= 0.999 && armed && phase == .compose {
                armed = false
                fuse(trigger: .fold)
            }
            if value < 0.5 { armed = true }
        } else {
            withAnimation(Theme.smooth) { foldProgress = 0 }
        }
    }

    /// Voice: transcript arrives from SpeechService when the user lets go of the mic.
    func fuse(withSpokenInstruction text: String) {
        instruction = text
        fuse(trigger: .voice)
    }

    func fuse(trigger: FuseTrigger) {
        guard phase != .fusing else { return }
        lastTrigger = trigger
        guard isReady else {
            withAnimation(Theme.smooth) { foldProgress = 0 }
            flash("Put something on a screen first")
            Haptics.warning()
            return
        }
        guard RevenueCatService.shared.canFuse else {
            withAnimation(Theme.smooth) { foldProgress = 0 }
            showPaywall = true
            return
        }
        guard AppConfig.hasOpenAI else {
            withAnimation(Theme.smooth) { foldProgress = 0 }
            flash("Add your OpenAI key in Settings")
            showSettings = true
            return
        }

        Haptics.heavy()
        previewTask?.cancel()
        withAnimation(Theme.melt) { foldProgress = 1 }
        phase = .fusing
        fusingStage = FuseEngine.Stage.reading.rawValue
        fusingStartedAt = Date()
        let spoken = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggested = spoken.isEmpty ? suggestions.first?.instruction : nil

        fuseTask?.cancel()
        fuseTask = Task { [weak self] in
            guard let self else { return }
            async let leftSnap = self.left.model.capture()
            async let rightSnap = self.right.model.capture()
            let (l, r) = await (leftSnap, rightSnap)
            guard !Task.isCancelled else { return }
            do {
                let engine = FuseEngine()
                let result = try await engine.fuse(left: l, right: r, instruction: spoken.isEmpty ? nil : spoken, suggested: suggested) { stage in
                    Task { @MainActor in self.fusingStage = stage.rawValue }
                }
                guard !Task.isCancelled else { return }
                self.finish(with: result)
            } catch {
                guard !Task.isCancelled else { return }
                Haptics.warning()
                withAnimation(Theme.smooth) {
                    self.phase = .failed(error.localizedDescription)
                    self.foldProgress = 0
                }
            }
        }
    }

    private func finish(with result: FuseResult) {
        Haptics.success()
        currentResult = result
        withAnimation(Theme.smooth) {
            phase = .result
            foldProgress = 0
        }
        HistoryStore.shared.add(result)
        RevenueCatService.shared.recordFuse()
        let device = UIDevice.current.model
        Task { await SupabaseService.shared.record(result, device: device, isPublic: true) }
    }

    func cancelFuse() {
        fuseTask?.cancel()
        fuseTask = nil
        withAnimation(Theme.smooth) {
            phase = .compose
            foldProgress = 0
        }
        armed = true
    }

    /// Run a follow-up: the result's suggestion becomes the instruction and both screens are fused again.
    func followUp(_ text: String) {
        instruction = text
        withAnimation(Theme.smooth) { phase = .compose }
        fuse(trigger: .followUp)
    }

    func refuse() {
        withAnimation(Theme.smooth) { phase = .compose }
        fuse(trigger: .seam)
    }

    func dismissResult() {
        withAnimation(Theme.smooth) {
            phase = .compose
            foldProgress = 0
        }
        instruction = ""
        armed = true
    }

    /// Put a result back on a screen so it can be fused with something new.
    func stage(_ result: FuseResult, on side: Pane.Side) {
        let pane = side == .left ? left : right
        pane.apply(.text(result.plainText), as: .notes)
        dismissResult()
        flash("Result placed on the \(side.title.lowercased()) screen")
    }

    func open(_ result: FuseResult) {
        currentResult = result
        withAnimation(Theme.smooth) { phase = .result }
    }

    func resetPanes() {
        left.reset()
        right.reset()
        instruction = ""
        flash("Cleared")
    }

    // MARK: Demo scenarios

    func apply(_ scenario: DemoScenario) {
        dismissResult()
        left.apply(scenario.left.preset, as: scenario.left.kind)
        right.apply(scenario.right.preset, as: scenario.right.kind)
        instruction = scenario.instruction ?? ""
        Haptics.medium()
        flash(scenario.title)
    }

    // MARK: Commands from intents / Back Tap / Shortcuts

    func handle(_ command: AppCommand) {
        switch command {
        case .fuse: fuse(trigger: .intent)
        case .listen: NotificationCenter.default.post(name: .fuseStartListening, object: nil)
        case .reset: resetPanes()
        case .demo(let id):
            if let s = DemoScenario.all.first(where: { $0.id == id }) { apply(s) }
        }
    }

    // MARK: Hints

    func flash(_ text: String) {
        hintTask?.cancel()
        withAnimation(Theme.snappy) { hint = text }
        hintTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(Theme.snappy) { self?.hint = nil }
        }
    }
}

extension Notification.Name {
    static let fuseStartListening = Notification.Name("fuse.startListening")
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Commands bus (App Intents → app)

enum AppCommand: Equatable {
    case fuse
    case listen
    case reset
    case demo(String)
}

@MainActor
@Observable
final class AppCommandBus {
    static let shared = AppCommandBus()
    var pending: AppCommand?
    var serial: Int = 0

    func send(_ command: AppCommand) {
        pending = command
        serial &+= 1
    }

    func take() -> AppCommand? {
        defer { pending = nil }
        return pending
    }
}
