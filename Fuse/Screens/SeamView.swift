import SwiftUI

// MARK: - SeamView
//
// The hinge, made visible. A hairline of energy along the fold that brightens as both
// screens fill up, and a core at its center that is the app's only "button":
//   • hold the core → fuse without folding
//   • hold the mic  → say what you want, let go to fuse
//   • pinch along the seam → squeeze the halves together
// The instruction (spoken or typed) rides on the seam as a small capsule.

struct SeamView: View {
    @Bindable var model: AppModel
    var fold: FoldGeometry
    var size: CGSize

    @State private var pressingCore = false
    @State private var listening = false
    @State private var awaitingTap = false
    @State private var pulse = false

    private var center: CGPoint { CGPoint(x: fold.frame.midX, y: fold.frame.midY) }
    private var ready: Double { Double(model.readiness) / 2 }

    var body: some View {
        ZStack {
            hairline
            core
        }
        .onAppear { pulse = true }
        .onReceive(NotificationCenter.default.publisher(for: .fuseStartListening)) { _ in
            beginListening(fromIntent: true)
        }
    }

    // MARK: Hairline

    private var hairline: some View {
        let intensity = 0.25 + 0.75 * max(ready, model.foldProgress)
        return Group {
            if fold.isVertical {
                Rectangle()
                    .fill(Theme.energyVertical)
                    .frame(width: 2, height: size.height * 0.7)
                    .blur(radius: 0.4)
                    .overlay(
                        Rectangle()
                            .fill(Theme.energyVertical)
                            .frame(width: 10)
                            .blur(radius: 14)
                            .opacity(0.5 + 0.5 * model.foldProgress)
                    )
            } else {
                Rectangle()
                    .fill(Theme.energy)
                    .frame(width: size.width * 0.7, height: 2)
                    .overlay(
                        Rectangle()
                            .fill(Theme.energy)
                            .frame(height: 10)
                            .blur(radius: 14)
                            .opacity(0.5 + 0.5 * model.foldProgress)
                    )
            }
        }
        .opacity(intensity)
        .position(center)
        .animation(Theme.smooth, value: model.readiness)
    }

    // MARK: Core

    private var core: some View {
        let stack = fold.isVertical
        return Group {
            if stack {
                VStack(spacing: 10) { coreOrb; micButton; instructionCapsule; suggestionStrip(vertical: true) }
            } else {
                HStack(spacing: 10) { suggestionStrip(vertical: false); instructionCapsule; micButton; coreOrb }
            }
        }
        .position(center)
        .gesture(seamPinch)
    }

    // MARK: Suggestions — what the model thinks the fold should do right now

    @ViewBuilder
    private func suggestionStrip(vertical: Bool) -> some View {
        if model.phase == .compose {
            let chips = Group {
                if model.isPreviewing && model.suggestions.isEmpty {
                    HStack(spacing: 6) {
                        Circle().fill(Theme.cyan).frame(width: 5, height: 5)
                            .opacity(pulse ? 1 : 0.3)
                            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                        Text("Reading both screens")
                            .font(.fuseCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                ForEach(Array(model.suggestions.enumerated()), id: \.element.id) { index, s in
                    let selected = (model.chosenSuggestion ?? model.suggestions.first)?.id == s.id && model.instruction.isEmpty || model.chosenSuggestion?.id == s.id
                    Button { model.choose(s) } label: {
                        HStack(spacing: 6) {
                            if selected {
                                Text("Fold →")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.cyan)
                            }
                            Image(systemName: s.resolvedSymbol)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                            Text(s.title)
                                .font(.system(size: 12, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(selected ? .regular.tint(Theme.violet.opacity(0.45)).interactive() : .regular.interactive(), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .animation(Theme.snappy.delay(Double(index) * 0.06), value: model.suggestions)
                }
            }
            if vertical {
                VStack(spacing: 6) { chips }.frame(maxWidth: 210)
            } else {
                HStack(spacing: 6) { chips }
            }
        }
    }

    private var coreOrb: some View {
        ZStack {
            Circle()
                .fill(Theme.energyAngular)
                .frame(width: 58, height: 58)
                .blur(radius: 16)
                .opacity((0.25 + 0.55 * ready) * (pulse ? 1 : 0.6))
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
            Circle()
                .fill(.clear)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
            FuseMark(progress: pressingCore ? 1 : ready)
                .frame(width: 22, height: 22)
                .foregroundStyle(Theme.textPrimary)
        }
        .scaleEffect(pressingCore ? 0.9 : 1)
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
                .frame(width: 34, height: 34)
                .glassEffect(.regular.interactive(), in: .circle)
            Image(systemName: listening ? "waveform" : "mic.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(listening ? Theme.cyan : Theme.textPrimary)
                .symbolEffect(.variableColor.iterative, isActive: listening)
        }
        .scaleEffect(listening ? 1.15 : 1)
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

    @ViewBuilder
    private var instructionCapsule: some View {
        let text = listening ? (SpeechService.shared.transcript.isEmpty ? "Listening…" : SpeechService.shared.transcript) : model.instruction
        if !text.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: listening ? "waveform" : "quote.opening")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.cyan)
                Text(text)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if !listening {
                    Button {
                        Haptics.tap()
                        withAnimation(Theme.snappy) { model.instruction = "" }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
            .frame(maxWidth: 200)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
            .onTapGesture { if !listening { model.showInstructionEditor = true } }
        } else {
            Button {
                model.showInstructionEditor = true
            } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 28, height: 28)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Type an instruction")
        }
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
        listening = true
        awaitingTap = fromIntent
        Task { await SpeechService.shared.start() }
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
                model.flash("Didn't catch that — hold and try again")
            } else {
                model.fuse(withSpokenInstruction: text)
            }
        }
    }
}

// MARK: - The mark

/// Two discs that overlap more as `progress` → 1. Doubles as the wordmark glyph.
struct FuseMark: View {
    var progress: Double = 0.5

    var body: some View {
        GeometryReader { geo in
            let d = geo.size.width * 0.62
            let gap = geo.size.width * (0.38 - 0.2 * progress)
            ZStack {
                Circle().stroke(lineWidth: geo.size.width * 0.09)
                    .frame(width: d, height: d)
                    .offset(x: -gap / 2)
                Circle().stroke(lineWidth: geo.size.width * 0.09)
                    .frame(width: d, height: d)
                    .offset(x: gap / 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(Theme.snappy, value: progress)
    }
}
