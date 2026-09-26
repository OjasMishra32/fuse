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
    /// After typing an instruction: invite the fold (the halves breathe toward the hinge).
    var foldPrompt = false
    var showScenarios = false

    // Intent preview: what the model thinks the fold should do, right now.
    var suggestions: [FuseSuggestion] = []
    var chosenSuggestion: FuseSuggestion?
    var isPreviewing = false
    private var previewTask: Task<Void, Never>?
    private var lastPreviewKey = ""

    private var fuseTask: Task<Void, Never>?
    private var armed = true
    private var hintTask: Task<Void, Never>?

    var readiness: Int { (left.model.hasContent && !left.isHome ? 1 : 0) + (right.model.hasContent && !right.isHome ? 1 : 0) }
    /// True when at least one half is showing the home screen (the system chrome shows then).
    var anyHome: Bool { left.isHome || right.isHome }
    var isReady: Bool { readiness >= 1 }
    var isFusing: Bool { phase == .fusing }

    /// Changes whenever the live content of either screen changes. Drives the intent preview.
    var contentKey: String {
        let leftPhotoRevision = (left.model as? PhotoSurfaceModel)?.contentRevision ?? 0
        let rightPhotoRevision = (right.model as? PhotoSurfaceModel)?.contentRevision ?? 0
        return "\(left.kind.rawValue)|\(left.isHome)|\(left.model.hasContent)|\(left.model.headline)|\(leftPhotoRevision)|\(right.kind.rawValue)|\(right.isHome)|\(right.model.hasContent)|\(right.model.headline)|\(rightPhotoRevision)"
    }

    /// What the fold will do if the user doesn't say otherwise.
    var defaultSuggestion: FuseSuggestion? { chosenSuggestion ?? suggestions.first }

    // MARK: Intent preview

    func schedulePreview() {
        let key = contentKey
        guard key != lastPreviewKey else { return }
        lastPreviewKey = key
        previewTask?.cancel()
        if let chosenSuggestion, instruction == chosenSuggestion.instruction {
            instruction = ""
        }
        chosenSuggestion = nil
        // A replacement photo must not inherit the previous photo's proposed edit
        // while the new preview is being debounced or fetched.
        suggestions = []
        isPreviewing = false
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
        foldPrompt = false
        withAnimation(Theme.melt) { foldProgress = 1 }
        phase = .fusing
        fusingStage = FuseEngine.Stage.reading.rawValue
        fusingStartedAt = Date()
        let spoken = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggested = spoken.isEmpty ? (screenshotMode ? nil : suggestions.first?.instruction) : nil
        let framing = screenshotMode ? Prompts.screenshotFraming : nil

        fuseTask?.cancel()
        fuseTask = Task { [weak self] in
            guard let self else { return }
            async let leftSnap = self.left.model.capture()
            async let rightSnap = self.right.model.capture()
            let (l, r) = await (leftSnap, rightSnap)
            guard !Task.isCancelled else { return }
            do {
                let engine = FuseEngine()
                let result = try await engine.fuse(left: l, right: r, instruction: spoken.isEmpty ? nil : spoken, suggested: suggested, framing: framing) { stage in
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
        screenshotMode = false
        foldPrompt = false
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

    // MARK: Share sheet inbox ("Send to Fuse" from any app)

    /// Everything that arrives from outside the app, in priority order: explicit hand-offs
    /// (share sheet, Safari popup, intents), then the pages the Safari extension saw the user
    /// read, then the clipboard. Called whenever Fuse comes to the front.
    /// Returns true when an explicit screenshot from the inbox started a fuse, so callers must
    /// not start a second one from the Photos fallback.
    @discardableResult
    func importSharedItems() -> Bool {
        AppConfig.syncToGroup()
        if let data = SharedInbox.defaults?.data(forKey: SharedInbox.lastBackgroundResultKey) {
            SharedInbox.defaults?.removeObject(forKey: SharedInbox.lastBackgroundResultKey)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let result = try? decoder.decode(FuseResult.self, from: data) {
                HistoryStore.shared.add(result)
                open(result)
                flash("Fused in Safari")
                return false
            }
        }
        let command = FuseCommandFlag.take()
        let consumedScreenshot = importInbox()
        if left.isHome && right.isHome {
            stageRecentPages()
            offerClipboard()
        }
        if consumedScreenshot {
            // The screenshot fuse is already running; nothing else may start a second one.
        } else if command == "fuse" {
            if readiness > 0 { fuse(trigger: .intent) } else { flash("Read something in Safari or copy something first") }
        } else if isClosed && readiness == 2 && phase == .compose && lastStagedFromRecents {
            // Opened from the cover with the phone already folded: the fold is the command.
            fuse(trigger: .fold)
        }
        lastStagedFromRecents = false
        return consumedScreenshot
    }

    private var lastStagedFromRecents = false
    private var lastPasteboardChange: Int = UIPasteboard.general.changeCount

    /// The last two pages the user read in Safari become the two halves.
    private func stageRecentPages() {
        let fresh = SharedInbox.recentVisits().filter { Date().timeIntervalSince($0.at) < 45 * 60 }
        guard let first = fresh.first else { return }
        if let a = URL(string: first.url) {
            left.apply(.url(a), as: .web)
        }
        if fresh.count > 1, let b = URL(string: fresh[1].url) {
            right.apply(.url(b), as: .web)
            flash("From Safari: \(first.title.prefix(28)) + \(fresh[1].title.prefix(28))")
        } else {
            flash("From Safari: \(first.title.prefix(40))")
        }
        lastStagedFromRecents = true
    }

    /// Something copied in another app goes on the first empty half.
    private func offerClipboard() {
        let board = UIPasteboard.general
        guard board.changeCount != lastPasteboardChange else { return }
        lastPasteboardChange = board.changeCount
        let target = right.isHome ? right : (left.isHome ? left : nil)
        guard let pane = target else { return }
        if board.hasURLs, let url = board.url {
            pane.apply(.url(url), as: .web)
            flash("From clipboard: \(url.host ?? "link")")
        } else if board.hasImages, let image = board.image {
            pane.apply(.image(image), as: .photo)
            flash("From clipboard: image")
        } else if board.hasStrings, let text = board.string, !text.isEmpty {
            pane.apply(.text(text), as: .notes)
            flash("From clipboard: \(text.prefix(30))…")
        }
    }

    /// Drain the inbox. Intake completes first; at most one screenshot fuse starts afterwards.
    /// Returns true when a screenshot fuse was started.
    private func importInbox() -> Bool {
        let items = SharedInbox.drain()
        guard !items.isEmpty else { return false }
        var screenshot: UIImage?
        for item in items {
            if item.kind == .screen {
                // Keep the newest explicit screenshot; older ones in the same batch are superseded.
                if let url = SharedInbox.fileURL(for: item), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    screenshot = image
                }
                continue
            }
            let pane = item.side == .left ? left : right
            switch item.kind {
            case .url:
                if let s = item.url, let url = URL(string: s) { pane.apply(.url(url), as: .web) }
                else if let text = item.text { pane.apply(.text(text), as: .notes) }
            case .text:
                pane.apply(.text(item.text ?? ""), as: .notes)
            case .image:
                if let url = SharedInbox.fileURL(for: item), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    pane.apply(.image(image), as: .photo)
                }
            case .file:
                if let url = SharedInbox.fileURL(for: item) { pane.apply(.document(url), as: .document) }
            case .screen:
                break
            }
        }
        if phase != .compose { dismissResult() }
        Haptics.medium()
        if let screenshot {
            // Intake is complete; now start exactly one fuse for the explicit screenshot.
            fuseScreenshot(screenshot)
            return true
        }
        let last = items[items.count - 1]
        flash("\(last.title) → \(last.side == .left ? "left" : "right") screen")
        return false
    }

    // MARK: Fuse anywhere — a screenshot of two apps side by side

    /// Split a screenshot of the open phone along the fold and fuse the two apps that were on it.
    /// This is how Fuse works from *any* app: Back Tap → Shortcut (Take Screenshot → Fuse Screenshot).
    /// `instruction` defaults to whatever is already typed/spoken; pass a value to replace it.
    func fuseScreenshot(_ image: UIImage, instruction: String? = nil) {
        let kept = instruction ?? self.instruction
        let (a, b) = Self.splitAtFold(image)
        if phase != .compose { dismissResult() }   // clears `instruction`; restored below
        left.apply(.image(a), as: .photo)
        right.apply(.image(b), as: .photo)
        self.instruction = kept
        screenshotMode = true
        Haptics.medium()
        fuse(trigger: .intent)
    }

    /// True while the current fuse came from a whole-screen capture (changes the prompt framing).
    var screenshotMode = false

    static func splitAtFold(_ image: UIImage) -> (UIImage, UIImage) {
        guard let crops = try? ScreenshotInput.crop(image, layout: .auto) else { return (image, image) }
        return (crops.first, crops.second)
    }

    /// Fallback for the intent when no screenshot was passed: the newest screenshot in Photos (last 3 minutes).
    func fuseLatestScreenshot() async {
        if let image = await LatestScreenshot.fetch(maxAge: 180) {
            fuseScreenshot(image)
        } else {
            flash("No recent screenshot — take one of both apps, then fuse")
        }
    }

    // MARK: Deep links (fuse://…) — Shortcuts, the extensions, and remote control

    /// fuse://demo?id=theme-park
    /// fuse://stage?side=left&url=https://…            (a page)
    /// fuse://stage?side=right&place=Name&lat=…&lon=…  (a map pin)
    /// fuse://stage?side=left&text=…                   (a note)
    /// fuse://fuse   fuse://home   fuse://screenshot   fuse://inbox
    func handle(url: URL) {
        importSharedItems()
        let host = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { q.first { $0.name == name }?.value }
        switch host {
        case "demo":
            if let id = value("id"), let s = DemoScenario.all.first(where: { $0.id == id }) { apply(s) }
        case "stage":
            let pane = value("side") == "right" ? right : left
            if phase != .compose { dismissResult() }
            if let u = value("url"), let link = URL(string: u) {
                pane.apply(.url(link), as: .web)
            } else if let name = value("place"), let lat = value("lat").flatMap(Double.init), let lon = value("lon").flatMap(Double.init) {
                pane.apply(.place(name: name, latitude: lat, longitude: lon), as: .maps)
            } else if let text = value("text") {
                let kind = SurfaceKind(rawValue: value("kind") ?? "") ?? .notes
                pane.apply(.text(text), as: kind)
            }
            if let text = value("instruction") { instruction = text }
            Haptics.tap()
        case "fuse":
            fuse(trigger: .intent)
        case "home":
            left.goHome(); right.goHome()
        case "screenshot":
            Task { await fuseLatestScreenshot() }
        default:
            break
        }
    }

    // MARK: Commands from intents / Back Tap / Shortcuts

    func handle(_ command: AppCommand) {
        switch command {
        case .fuse:
            if readiness == 0 { Task { await fuseLatestScreenshot() } } else { fuse(trigger: .intent) }
        case .fuseScreenshot:
            // An explicit screenshot from the intent wins; only fall back to Photos when none arrived.
            let consumed = importSharedItems()
            if !consumed && !screenshotMode { Task { await fuseLatestScreenshot() } }
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
    case fuseScreenshot
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
