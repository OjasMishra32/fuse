import SwiftUI
import AVFoundation

// MARK: - SeamView
//
// The hinge, made just visible enough. A hairline along the fold and, at its center, the
// only control in the app, the orb:
//   • hold the core → fuse without folding
//   • hold the mic  → say what you want, let go to fuse
//   • pinch along the seam → squeeze the halves together
// Below it, what the model thinks the fold should do right now, as plain chips.

struct SeamView: View {
    @Bindable var model: AppModel
    var fold: FoldGeometry
    var size: CGSize

    @State private var pressingCore = false
    @State private var listening = false
    @State private var awaitingTap = false
    private var center: CGPoint { CGPoint(x: fold.frame.midX, y: fold.frame.midY) }

    var body: some View {
        ZStack {
            hairline
            if model.foldPrompt && model.phase == .compose { sweep; foldInvite }
            core
        }
        .onReceive(NotificationCenter.default.publisher(for: .fuseStartListening)) { _ in
            beginListening(fromIntent: true)
        }
    }

    // MARK: Hairline

    private var hairline: some View {
        let color = model.readiness == 2 ? Color.accentColor.opacity(0.55) : Theme.line
        return Group {
            if fold.isVertical {
                Rectangle().fill(color).frame(width: 1, height: size.height + 300)
            } else {
                Rectangle().fill(color).frame(width: size.width + 300, height: 1)
            }
        }
        .position(center)
        .animation(Theme.smooth, value: model.readiness)
        .contentShape(Rectangle().size(width: 44, height: size.height))
        .onTapGesture(count: 3) {
            Haptics.rigid()
            withAnimation(Theme.snappy) { model.showDevPanel.toggle() }
        }
    }

    // MARK: Fold invite (after typing an instruction)

    private var sweep: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: 1.6)) / 1.6
            let length = fold.isVertical ? size.height : size.width
            let offset = CGFloat(phase) * length - length / 2
            Capsule()
                .fill(Color.accentColor)
                .frame(width: fold.isVertical ? 3 : 90, height: fold.isVertical ? 90 : 3)
                .blur(radius: 1.5)
                .opacity(0.9)
                .position(x: center.x + (fold.isVertical ? 0 : offset), y: center.y + (fold.isVertical ? offset : 0))
        }
        .allowsHitTesting(false)
    }

    private var foldInvite: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                OrbView(size: 18, animated: true, intensity: 1)
                    .frame(width: 22, height: 22)
                Text("Fold to fuse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Text(model.instruction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 200)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .fixedSize()
        .position(x: center.x, y: center.y - 92)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .onTapGesture { withAnimation(Theme.snappy) { model.foldPrompt = false } }
    }

    // MARK: Core

    private var core: some View {
        Group {
            if fold.isVertical {
                VStack(spacing: 12) {
                    GlassEffectContainer(spacing: 8) {
                        VStack(spacing: 8) { coreOrb; micButton }
                    }
                    intentPill
                }
            } else {
                HStack(spacing: 12) {
                    intentPill
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) { micButton; coreOrb }
                    }
                }
            }
        }
        .position(center)
        .gesture(seamPinch)
    }

    /// Orb brightness: dim with nothing staged, full when both halves are ready or while pressing.
    private var coreIntensity: Double {
        if pressingCore { return 1 }
        switch model.readiness {
        case 0: return 0.3
        case 1: return 0.65
        default: return 1
        }
    }

    private var coreOrb: some View {
        ZStack {
            if model.readiness == 2 {
                Circle()
                    .fill(Color.accentColor.opacity(0.25))
                    .frame(width: 58, height: 58)
                    .blur(radius: 18)
                    .phaseAnimator([0.95, 1.25]) { view, scale in
                        view.scaleEffect(scale)
                    } animation: { _ in
                        .easeInOut(duration: 2.2)
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            Circle()
                .fill(.clear)
                .frame(width: 58, height: 58)
                .glassEffect(.regular.interactive(), in: .circle)
            OrbView(size: 48, animated: true, intensity: coreIntensity, speed: 0.8)
                .allowsHitTesting(false)
        }
        .animation(Theme.smooth, value: model.readiness)
        .scaleEffect(pressingCore ? 0.92 : 1)
        .animation(Theme.snappy, value: pressingCore)
        .onLongPressGesture(minimumDuration: 0.55, maximumDistance: 30) {
            pressingCore = false
            model.fuse(trigger: .seam)
        } onPressingChanged: { pressing in
            guard model.phase == .compose else { return }
            pressingCore = pressing
            if pressing { Haptics.soft() }
            withAnimation(pressing ? .easeIn(duration: 0.55) : Theme.smooth) {
                model.foldProgress = pressing ? 0.6 : 0
            }
        }
        .accessibilityLabel("Fuse")
        .accessibilityHint("Hold to fuse both screens")
    }

    private var micButton: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.interactive(), in: .circle)
            Image(systemName: listening ? "waveform" : "mic.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(listening ? Color.accentColor : Color.primary)
                .symbolEffect(.variableColor.iterative, isActive: listening)
        }
        .scaleEffect(listening ? 1.12 : 1)
        .animation(Theme.snappy, value: listening)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !listening && !awaitingTap { beginListening(fromIntent: false) }
                }
                .onEnded { _ in
                    if awaitingTap {
                        awaitingTap = false
                        endListeningAndFuse()
                    } else if listening {
                        endListeningAndFuse()
                    }
                }
        )
        .accessibilityLabel("Speak an instruction")
        .accessibilityHint("Hold, say what to make, let go")
    }

    // MARK: One pill: what the fold will do. Tap for the alternatives.

    @ViewBuilder
    private var intentPill: some View {
        if model.phase == .compose && !model.foldPrompt {
            if listening {
                pillLabel(symbol: "waveform", text: SpeechService.shared.transcript.isEmpty ? "Listening…" : SpeechService.shared.transcript, prominent: true)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if !model.instruction.isEmpty {
                Menu {
                    Button("Change…", systemImage: "keyboard") { model.showInstructionEditor = true }
                    Button("Clear instruction", systemImage: "xmark.circle", role: .destructive) {
                        withAnimation(Theme.snappy) { model.instruction = ""; model.chosenSuggestion = nil }
                    }
                } label: {
                    pillLabel(symbol: "text.quote", text: "Fold: \(model.instruction)", prominent: true)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if let top = model.defaultSuggestion {
                Menu {
                    ForEach(model.suggestions) { s in
                        Button(s.title, systemImage: s.resolvedSymbol) { model.choose(s) }
                    }
                    Divider()
                    Button("Type an instruction…", systemImage: "keyboard") { model.showInstructionEditor = true }
                } label: {
                    pillLabel(symbol: top.resolvedSymbol, text: "Fold: \(top.title)", prominent: true)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if model.isPreviewing {
                pillLabel(symbol: "circle.dotted", text: "Reading both screens", prominent: false)
                    .transition(.opacity)
            } else if model.readiness > 0 {
                Button {
                    model.showInstructionEditor = true
                } label: {
                    pillLabel(symbol: "keyboard", text: "Fold, or say what to make", prominent: false)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
    }

    private func pillLabel(symbol: String, text: String, prominent: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
            Text(text)
                .font(.footnote.weight(prominent ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(prominent ? Color.accentColor : Color.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .frame(maxWidth: 240)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: Pinch along the seam

    private var seamPinch: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.02)
            .onChanged { value in
                let progress = (1 - value.magnification) / 0.45
                model.setPinch(progress: max(progress, 0), ended: false)
            }
            .onEnded { value in
                let progress = (1 - value.magnification) / 0.45
                model.setPinch(progress: max(progress, 0), ended: true)
            }
    }

    // MARK: Voice

    private func beginListening(fromIntent: Bool) {
        guard model.phase == .compose, !listening else { return }
        Haptics.medium()
        // No microphone (the simulator, or a denied permission): type instead. Same fuse, no dead end.
        guard AVAudioSession.sharedInstance().isInputAvailable else {
            model.flash("No microphone here, type it instead")
            model.showInstructionEditor = true
            return
        }
        listening = true
        awaitingTap = fromIntent
        Task {
            await SpeechService.shared.start()
            if let err = SpeechService.shared.errorText {
                listening = false
                awaitingTap = false
                model.flash(err)
                model.showInstructionEditor = true
            }
        }
    }

    private func endListeningAndFuse() {
        SpeechService.shared.stop()
        Haptics.rigid()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            let text = SpeechService.shared.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            listening = false
            if let err = SpeechService.shared.errorText, text.isEmpty {
                model.flash(err)
                return
            }
            if text.isEmpty {
                model.flash("Didn't catch that. Hold and try again")
            } else {
                model.fuse(withSpokenInstruction: text)
            }
        }
    }
}

/// Type-erased primitive button style so a chip can switch between bordered and prominent.
struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: PrimitiveButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}
