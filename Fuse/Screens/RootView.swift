import SwiftUI

// MARK: - RootView
//
// Picks what the current display shows: the cover (closed), the stage (open, composing),
// the fusing overlay, or the result. Owns the hint toast, all sheets and the command bus
// from App Intents.

struct RootView: View {
    @Bindable var model: AppModel
    @State private var devFold: Double = 0
    @State private var bus = AppCommandBus.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.background

            if model.jobDemoActive && model.jobShowingResult {
                JobApplicationWorkspaceView(model: model)
            } else if model.isClosed {
                CoverView(model: model)
            } else {
                mainStage
            }

            if let hint = model.hint {
                toast(hint)
            }

            if model.showDevPanel && !model.isClosed {
                devPanel
            }
        }
        .fuseHingeTracking(model)
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
        .sheet(isPresented: $model.showScenarios) { ScenariosSheet(model: model) }
        .onChange(of: bus.serial) { _, _ in
            if let command = bus.take() { model.handle(command) }
        }
        .onChange(of: model.contentKey) { _, _ in
            model.schedulePreview()
        }
        .onChange(of: scenePhase) { _, phase in
            model.jobSceneActive = phase == .active
            if phase == .active {
                model.importSharedItems()
                if !model.jobDemoActive { model.attachOrb() }
            }
        }
        .onOpenURL { url in
            model.handle(url: url)
        }
        .onDisappear { model.jobWorkspaceVisible = false }
        .onAppear {
            model.jobWorkspaceVisible = true
            model.jobSceneActive = scenePhase == .active
            RevenueCatService.shared.configure()
            Task { await SupabaseService.shared.ensureSession() }
            if let command = bus.take() { model.handle(command) }
            model.importSharedItems()
            model.schedulePreview()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { if !model.jobDemoActive { model.attachOrb() } }
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
                    Rectangle().fill(.regularMaterial).ignoresSafeArea()
                    FailureCard(message: message, onRetry: { model.refuse() }, onDismiss: { model.dismissResult() })
                }
                .transition(.opacity)
            }
        }
        .animation(Theme.smooth, value: model.phase)
    }

    // MARK: Toast

    private func toast(_ hint: String) -> some View {
        Text(hint)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
            .frame(maxWidth: 360)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, Theme.margin)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: Dev panel (triple-tap the seam)

    private var devPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: "Rehearse the fold")
                Spacer()
                Button {
                    model.setDebugFold(nil)
                    withAnimation(Theme.snappy) { model.showDevPanel = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .accessibilityLabel("Close")
            }
            HStack(spacing: 12) {
                Image(systemName: "ipad.landscape")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Slider(value: $devFold, in: 0...1)
                    .onChange(of: devFold) { _, value in model.setDebugFold(value) }
                    .accessibilityLabel("Fold progress")
                Image(systemName: "iphone.gen3")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    GlassButton(title: "Open", symbol: "arrow.left.and.right") { devFold = 0; model.setDebugFold(0) }
                    GlassButton(title: "Half", symbol: "laptopcomputer") { devFold = 0.55; model.setDebugFold(0.55) }
                    GlassButton(title: "Close and Fuse", symbol: "bolt.fill") { devFold = 1; model.setDebugFold(1) }
                    GlassButton(title: "Release", symbol: "hand.raised") { model.setDebugFold(nil) }
                }
                .controlSize(.small)
            }
            Text("Hinge \(Int(model.hingeDegrees))°  ·  progress \(String(format: "%.2f", model.foldProgress))  ·  trigger \(model.lastTrigger?.rawValue ?? "none")")
                .font(.fuseMono)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(Theme.margin)
        .frame(maxWidth: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, Theme.margin)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - ResultScreen (inner display)

/// Wraps the shared ResultView with the stage-specific actions: put the result back on a screen.
struct ResultScreen: View {
    @Bindable var model: AppModel
    var result: FuseResult

    var body: some View {
        VStack(spacing: 0) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        Haptics.tap()
                        model.dismissResult()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .lineLimit(1)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    Spacer(minLength: 0)
                    Button {
                        Haptics.tap()
                        model.stage(result, on: .left)
                    } label: {
                        Label("Keep on Left", systemImage: "rectangle.lefthalf.inset.filled")
                            .lineLimit(1)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    Button {
                        Haptics.tap()
                        model.stage(result, on: .right)
                    } label: {
                        Label("Keep on Right", systemImage: "rectangle.righthalf.inset.filled")
                            .lineLimit(1)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                }
                .controlSize(.small)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 8)
            .padding(.bottom, 8)

            ResultView(
                result: result,
                compact: false,
                showsClose: false,
                onFollowUp: { model.followUp($0) },
                onDismiss: { model.dismissResult() },
                onRefuse: { model.refuse() }
            )
        }
        .background { Theme.grouped.ignoresSafeArea() }
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
            Form {
                Section {
                    TextField("Make a one-day plan, or Draft the reply", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focused)
                } header: {
                    Text("What should the fuse do?")
                } footer: {
                    Text("Optional. Without an instruction, Fuse infers the most useful result from the relationship between the two screens.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Instruction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        model.instruction = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        model.foldPrompt = !model.instruction.isEmpty && model.readiness > 0
                        if model.foldPrompt { Haptics.medium() }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { text = model.instruction; focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Scenarios (demo content, presented like an app)

struct ScenariosSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(DemoScenario.sections) { section in
                    Section {
                        ForEach(section.scenarios) { scenario in
                            Button {
                                Haptics.tap()
                                dismiss()
                                model.apply(scenario)
                            } label: {
                                HStack(spacing: 12) {
                                    IconTile(symbol: scenario.symbol, tint: .accentColor, size: 30)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(scenario.title)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(scenario.subtitle)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(section.title)
                            Spacer()
                            Text("\(section.scenarios.count)")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        Haptics.tap()
                        dismiss()
                        model.resetPanes()
                    } label: {
                        Label("Clear Both Halves", systemImage: "xmark.circle")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Scenarios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}
