import SwiftUI
import AVFoundation

// MARK: - SeamView
//
// The hinge, made just visible enough. A hairline along the fold and, at its center, the
// only control in the app, the orb:
//   • hold the core → fuse without folding
//   • hold the mic  → say what you want, let go to fuse
//   • pinch along the seam → squeeze the halves together
// Below it, what the model thinks the fold should do right now, as one pill.

struct SeamView: View {
    @Bindable var model: AppModel
    var fold: FoldGeometry
    var size: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pressingCore = false
    @State private var listening = false
    @State private var awaitingTap = false

    private var center: CGPoint { CGPoint(x: fold.frame.midX, y: fold.frame.midY) }
    private var inviting: Bool { model.foldPrompt && model.phase == .compose }

    var body: some View {
        ZStack {
            hairline
            if inviting { sweep }
            core
        }
        .onReceive(NotificationCenter.default.publisher(for: .fuseStartListening)) { _ in
            beginListening(fromIntent: true)
        }
    }

    // MARK: Hairline

    private var hairline: some View {
        let color = model.readiness == 2 ? Color.accentColor.opacity(0.55) : Theme.line
        // The tap zone is the hinge itself, never the halves' content beside it.
        let zone = max(fold.isVertical ? fold.frame.width : fold.frame.height, 12)
        return Group {
            if fold.isVertical {
                Rectangle().fill(color)
                    .frame(width: 1, height: size.height + 300)
                    .frame(width: zone)
            } else {
                Rectangle().fill(color)
                    .frame(width: size.width + 300, height: 1)
                    .frame(height: zone)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 3) {
            Haptics.rigid()
            withAnimation(Theme.snappy) { model.showDevPanel.toggle() }
        }
        .position(center)
        .animation(Theme.smooth, value: model.readiness)
    }

    // MARK: Fold invite (after typing an instruction)

    /// A pulse of accent light travelling along the seam. With Reduce Motion it rests at the
    /// centre as a still glow instead of sweeping.
    @ViewBuilder
    private var sweep: some View {
        if reduceMotion {
            Capsule()
                .fill(Color.accentColor)
                .frame(width: fold.isVertical ? 3 : 90, height: fold.isVertical ? 90 : 3)
                .blur(radius: 1.5)
                .opacity(0.7)
                .position(center)
                .allowsHitTesting(false)
        } else {
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
    }

    private var foldInvite: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                OrbGlyph(size: 20)
                Text("Fold to fuse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Text(model.instruction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .frame(maxWidth: 240)
        .modifier(GentleFloat(distance: 2, period: 2.4))
        .onTapGesture { withAnimation(Theme.snappy) { model.foldPrompt = false } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Dismisses the reminder")
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: Core

    private var core: some View {
        Group {
            if fold.isVertical {
                VStack(spacing: 12) {
                    GlassEffectContainer(spacing: 10) {
                        VStack(spacing: 10) { coreOrb; micButton }
                    }
                    intentPill(alignment: .center)
                }
            } else {
                HStack(spacing: 12) {
                    intentPill(alignment: .trailing)
                    GlassEffectContainer(spacing: 10) {
                        HStack(spacing: 10) { micButton; coreOrb }
                    }
                }
            }
        }
        // The invite sits 12pt above the core, whichever way the fold runs, so it never overlaps it.
        .overlay(alignment: .top) {
            if inviting {
                foldInvite
                    .alignmentGuide(.top) { $0[.bottom] + 12 }
            }
        }
        .animation(Theme.snappy, value: model.foldPrompt)
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
            Circle()
                .fill(.clear)
                .frame(width: 58, height: 58)
                .glassEffect(.regular.interactive(), in: .circle)
            // Intensity is interpolated here so both halves becoming ready brightens the orb
            // over 0.6 s; a press brightens with the same spring that scales it.
            IntensityOrb(size: 48, animated: !reduceMotion, intensity: coreIntensity, speed: 0.8)
                .animation(pressingCore ? Theme.snappy : .easeInOut(duration: 0.6), value: coreIntensity)
                .allowsHitTesting(false)
        }
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
        .accessibilityElement()
        .accessibilityLabel("Fuse")
        .accessibilityHint("Hold to fuse both screens")
        .accessibilityAddTraits(.isButton)
    }

    private var micButton: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
            Image(systemName: listening ? "waveform" : "mic.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(listening ? Color.accentColor : Color.primary)
                .symbolEffect(.variableColor.iterative, isActive: listening)
        }
        .scaleEffect(listening ? 1.08 : 1)
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
        .accessibilityElement()
        .accessibilityLabel("Speak an instruction")
        .accessibilityHint("Hold, say what to make, let go")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: One pill: what the fold will do. Tap for the alternatives.

    /// The pill hugs its text up to 260pt; `alignment` says where it sits inside that footprint.
    @ViewBuilder
    private func intentPill(alignment: Alignment) -> some View {
        Group {
            // Each branch means something different, so a branch swap blurs through; text that
            // changes inside a branch (the transcript, a new suggestion) crossfades in place.
            if model.phase == .compose && !model.foldPrompt {
                if listening {
                    pillLabel(symbol: "waveform", text: SpeechService.shared.transcript.isEmpty ? "Listening…" : SpeechService.shared.transcript, prominent: true)
                        .transition(.blurReplace)
                } else if !model.instruction.isEmpty {
                    Menu {
                        Button("Change…", systemImage: "keyboard") { model.showInstructionEditor = true }
                        Button("Clear Instruction", systemImage: "xmark.circle", role: .destructive) {
                            withAnimation(Theme.snappy) { model.instruction = ""; model.chosenSuggestion = nil }
                        }
                    } label: {
                        pillLabel(symbol: "text.quote", text: "Fold: \(model.instruction)", prominent: true)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .transition(.blurReplace)
                } else if let top = model.defaultSuggestion {
                    Menu {
                        ForEach(model.suggestions) { s in
                            Button(s.title, systemImage: s.resolvedSymbol) { model.choose(s) }
                        }
                        Divider()
                        Button("Type an Instruction…", systemImage: "keyboard") { model.showInstructionEditor = true }
                    } label: {
                        pillLabel(symbol: top.resolvedSymbol, text: "Fold: \(top.title)", prominent: true)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .transition(.blurReplace)
                } else if model.isPreviewing {
                    pillLabel(symbol: "circle.dotted", text: "Reading both screens", prominent: false)
                        .transition(.blurReplace)
                } else if model.readiness > 0 {
                    Button {
                        model.showInstructionEditor = true
                    } label: {
                        pillLabel(symbol: "keyboard", text: "Fold, or say what to make", prominent: false)
                    }
                    .buttonStyle(.plain)
                    .transition(.blurReplace)
                }
            }
        }
        .frame(maxWidth: 260, alignment: alignment)
        .animation(Theme.snappy, value: model.instruction)
        .animation(Theme.snappy, value: model.defaultSuggestion)
        .animation(Theme.snappy, value: model.isPreviewing)
        .animation(Theme.snappy, value: model.readiness)
        .animation(Theme.snappy, value: listening)
    }

    private func pillLabel(symbol: String, text: String, prominent: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .contentTransition(.symbolEffect(.replace))
            Text(text)
                .font(.subheadline.weight(prominent ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .contentTransition(.opacity)
        }
        .foregroundStyle(prominent ? Color.accentColor : Color.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .glassEffect(.regular.interactive(), in: .capsule)
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

// MARK: - Motion helpers

/// An orb whose `intensity` is animatable, so a change of readiness can be eased over a
/// chosen duration instead of jumping. Everything else is the plain `OrbView`.
private struct IntensityOrb: View, Animatable {
    var size: CGFloat
    var animated: Bool
    var intensity: Double
    var speed: Double

    var animatableData: Double {
        get { intensity }
        set { intensity = newValue }
    }

    var body: some View {
        OrbView(size: size, animated: animated, intensity: intensity, speed: speed)
    }
}

/// A slow vertical drift of a few points, the way a hint hovers. Off with Reduce Motion.
private struct GentleFloat: ViewModifier {
    var distance: CGFloat
    var period: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false

    func body(content: Content) -> some View {
        content
            .offset(y: lifted ? -distance : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: period).repeatForever(autoreverses: true),
                value: lifted
            )
            .onAppear {
                guard !reduceMotion else { return }
                lifted = true
            }
            .onDisappear { lifted = false }
    }
}
