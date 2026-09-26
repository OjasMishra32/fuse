import SwiftUI

// MARK: - RootView
//
// Picks what the current display shows: the cover (closed), the stage (open, composing),
// the fusing overlay, or the result. Owns the top bar, the hint toast, all sheets and the
// command bus from App Intents.

struct RootView: View {
    @Bindable var model: AppModel
    @State private var devFold: Double = 0
    @State private var bus = AppCommandBus.shared

    var body: some View {
        ZStack {
            Theme.background

            if model.isClosed {
                CoverView(model: model)
            } else {
                mainStage
                topBar
            }

            if let hint = model.hint {
                Text(hint)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassEffect(.regular, in: .capsule)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if model.showDevPanel && !model.isClosed {
                devPanel
            }
        }
        .fuseHingeTracking(model)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $model.showSettings) { SettingsView(onDismiss: { model.showSettings = false }) }
        .sheet(isPresented: $model.showHistory) {
            HistoryView(onOpen: { result in
                model.showHistory = false
                model.open(result)
            })
        }
        .sheet(isPresented: $model.showCommunity) {
            CommunityView(onOpen: { result in
                model.showCommunity = false
                model.open(result)
            })
        }
        .sheet(isPresented: $model.showPaywall) { PaywallView(onDismiss: { model.showPaywall = false }) }
        .sheet(isPresented: $model.showInstructionEditor) { InstructionEditor(model: model) }
        .onChange(of: bus.serial) { _, _ in
            if let command = bus.take() { model.handle(command) }
        }
        .onChange(of: model.contentKey) { _, _ in
            model.schedulePreview()
        }
        .onAppear {
            RevenueCatService.shared.configure()
            Task { await SupabaseService.shared.ensureSession() }
            if let command = bus.take() { model.handle(command) }
            model.schedulePreview()
        }
    }

    // MARK: Stage / result / fusing

    @ViewBuilder
    private var mainStage: some View {
        ZStack {
            switch model.phase {
            case .result:
                if let result = model.currentResult {
                    ResultScreen(model: model, result: result)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.94).combined(with: .opacity),
                            removal: .opacity))
                }
            default:
                StageView(model: model)
            }

            if model.phase == .fusing {
                FusingView(model: model)
                    .transition(.opacity)
            }

            if case .failed(let message) = model.phase {
                ZStack {
                    Theme.ink.opacity(0.7).ignoresSafeArea()
                    FailureCard(message: message, onRetry: { model.refuse() }, onDismiss: { model.dismissResult() })
                }
                .transition(.opacity)
            }
        }
        .animation(Theme.smooth, value: model.phase)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                FuseMark(progress: Double(model.readiness) / 2)
                    .frame(width: 16, height: 16)
                Text("Fuse")
                    .font(.fuseWordmark)
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassEffect(.regular, in: .capsule)
            .onTapGesture(count: 3) {
                Haptics.rigid()
                withAnimation(Theme.snappy) { model.showDevPanel.toggle() }
            }

            HingeBadge(hinge: model.hinge)

            Spacer(minLength: 0)

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(DemoScenario.all) { scenario in
                            Button {
                                model.apply(scenario)
                            } label: {
                                Label(scenario.title, systemImage: scenario.symbol)
                                Text(scenario.subtitle)
                            }
                        }
                        Divider()
                        Button(role: .destructive) { model.resetPanes() } label: {
                            Label("Clear both screens", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 34, height: 34)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)

                    GlassIconButton(symbol: "clock.arrow.circlepath", size: 34) { model.showHistory = true }
                    GlassIconButton(symbol: "person.2", size: 34) { model.showCommunity = true }
                    GlassIconButton(symbol: "gearshape", size: 34) { model.showSettings = true }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(model.phase == .fusing ? 0 : 1)
        .animation(Theme.snappy, value: model.phase == .fusing)
    }

    // MARK: Dev panel (triple-tap the wordmark)

    private var devPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "Rehearse the fold")
                Spacer()
                Button {
                    model.setDebugFold(nil)
                    withAnimation(Theme.snappy) { model.showDevPanel = false }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 10) {
                Image(systemName: "ipad.landscape").foregroundStyle(Theme.textTertiary)
                Slider(value: $devFold, in: 0...1)
                    .tint(Theme.violet)
                    .onChange(of: devFold) { _, value in model.setDebugFold(value) }
                Image(systemName: "iphone.gen3").foregroundStyle(Theme.textTertiary)
            }
            HStack(spacing: 8) {
                GlassButton(title: "Open", symbol: "arrow.left.and.right") { devFold = 0; model.setDebugFold(0) }
                GlassButton(title: "Half", symbol: "laptopcomputer") { devFold = 0.55; model.setDebugFold(0.55) }
                GlassButton(title: "Close → fuse", symbol: "bolt.fill") { devFold = 1; model.setDebugFold(1) }
                GlassButton(title: "Release", symbol: "hand.raised") { model.setDebugFold(nil) }
            }
            Text("Hinge: \(Int(model.hingeDegrees))°  ·  progress \(String(format: "%.2f", model.foldProgress))  ·  trigger \(model.lastTrigger?.rawValue ?? "—")")
                .font(.fuseMono)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(14)
        .frame(width: 420)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.radiusCard))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 14)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - ResultScreen (inner display)

/// Wraps the shared ResultView with the stage-specific actions: put the result back on a screen.
struct ResultScreen: View {
    @Bindable var model: AppModel
    var result: FuseResult

    var body: some View {
        ZStack(alignment: .top) {
            ResultView(
                result: result,
                compact: false,
                onFollowUp: { model.followUp($0) },
                onDismiss: { model.dismissResult() },
                onRefuse: { model.refuse() }
            )
            .padding(.top, 40)

            HStack(spacing: 8) {
                GlassButton(title: "Back", symbol: "chevron.left") { model.dismissResult() }
                Spacer()
                GlassButton(title: "Keep on left", symbol: "rectangle.lefthalf.inset.filled") { model.stage(result, on: .left) }
                GlassButton(title: "Keep on right", symbol: "rectangle.righthalf.inset.filled") { model.stage(result, on: .right) }
            }
            .padding(.horizontal, 12)
            .padding(.top, 50)
        }
    }
}

// MARK: - InstructionEditor

struct InstructionEditor: View {
    @Bindable var model: AppModel
    @State private var text: String = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "What should the fuse do?")
                TextField("e.g. Make a one-day plan, or Draft the reply", text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.fuseBody)
                    .padding(12)
                    .background(Theme.ink2, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                    .focused($focused)
                Text("Optional. Without an instruction, Fuse infers the most useful result from the relationship between the two screens.")
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
            }
            .padding(20)
            .background(Theme.background)
            .navigationTitle("Instruction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        model.instruction = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { text = model.instruction; focused = true }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}
