import SwiftUI

// MARK: - SeamView
//
// The hinge, made just visible enough. A hairline along the fold and, at its center, the
// only control in the app:
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
        let color = model.readiness == 2 ? Color.accentColor.opacity(0.55) : Theme.line
        return Group {
            if fold.isVertical {
                Rectangle().fill(color).frame(width: 1, height: size.height)
            } else {
                Rectangle().fill(color).frame(width: size.width, height: 1)
            }
        }
        .position(center)
        .animation(Theme.smooth, value: model.readiness)
    }

    // MARK: Core

    private var core: some View {
        Group {
            if fold.isVertical {
                VStack(spacing: 10) { coreOrb; micButton; instructionCapsule; suggestionStrip(vertical: true) }
            } else {
                HStack(spacing: 10) { suggestionStrip(vertical: false); instructionCapsule; micButton; coreOrb }
            }
        }
        .position(center)
        .gesture(seamPinch)
    }

    private var coreOrb: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive(), in: .circle)
            FuseMark(progress: pressingCore ? 1 : ready)
                .frame(width: 22, height: 22)
                .foregroundStyle(model.readiness == 2 ? Color.accentColor : Color.primary)
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

    @ViewBuilder
    private var instructionCapsule: some View {
        let text = listening ? (SpeechService.shared.transcript.isEmpty ? "Listening…" : SpeechService.shared.transcript) : model.instruction
        if !text.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: listening ? "waveform" : "text.quote")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if !listening {
                    Button {
                        Haptics.tap()
                        withAnimation(Theme.snappy) { model.instruction = ""; model.chosenSuggestion = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(maxWidth: 220)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
            .onTapGesture { if !listening { model.showInstructionEditor = true } }
        } else {
            Button {
                model.showInstructionEditor = true
            } label: {
                Image(systemName: "keyboard")
                    .font(.caption.weight(.medium))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Type an instruction")
        }
    }

    // MARK: Suggestions

    @ViewBuilder
    private func suggestionStrip(vertical: Bool) -> some View {
        if model.phase == .compose {
            let chips = Group {
                if model.isPreviewing && model.suggestions.isEmpty {
                    HStack(spacing: 6) {
                        Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                            .opacity(pulse ? 1 : 0.3)
                            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                        Text("Reading both screens")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
                ForEach(Array(model.suggestions.enumerated()), id: \.element.id) { index, s in
                    let isDefault = model.defaultSuggestion?.id == s.id
                    Button {
                        model.choose(s)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: s.resolvedSymbol)
                            Text(isDefault ? "Fold: \(s.title)" : s.title)
                                .lineLimit(1)
                        }
                        .font(.footnote.weight(isDefault ? .semibold : .regular))
                    }
                    .buttonStyle(isDefault ? AnyPrimitiveButtonStyle(.borderedProminent) : AnyPrimitiveButtonStyle(.bordered))
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .animation(Theme.snappy.delay(Double(index) * 0.05), value: model.suggestions)
                }
            }
            if vertical {
                VStack(spacing: 6) { chips }.frame(maxWidth: 220)
            } else {
                HStack(spacing: 6) { chips }
            }
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

// MARK: - The mark

/// Two rings that overlap more as `progress` → 1.
struct FuseMark: View {
    var progress: Double = 0.5

    var body: some View {
        GeometryReader { geo in
            let d = geo.size.width * 0.62
            let gap = geo.size.width * (0.38 - 0.2 * progress)
            ZStack {
                Circle().stroke(lineWidth: geo.size.width * 0.085)
                    .frame(width: d, height: d)
                    .offset(x: -gap / 2)
                Circle().stroke(lineWidth: geo.size.width * 0.085)
                    .frame(width: d, height: d)
                    .offset(x: gap / 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(Theme.snappy, value: progress)
    }
}
