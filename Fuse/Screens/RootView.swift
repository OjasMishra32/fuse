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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.background

            if model.jobDemoActive {
                JobApplicationWorkspaceView(model: model)
            } else if model.isClosed {
                CoverView(model: model)
            } else {
                mainStage
                if model.anyHome && model.phase == .compose {
                    topBar.transition(.opacity)
                }
            }

            if let hint = model.hint {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
        HStack {
            HingeBadge(hinge: model.hinge)
                .padding(.leading, 4)
                .contentShape(Rectangle())
                .onTapGesture(count: 3) {
                    Haptics.rigid()
                    withAnimation(Theme.snappy) { model.showDevPanel.toggle() }
                }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(Theme.snappy, value: model.anyHome)
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
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
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
                    .background(Theme.groupedCard, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                    .focused($focused)
                Text("Optional. Without an instruction, Fuse infers the most useful result from the relationship between the two screens.")
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
            }
            .padding(20)
            .background(Theme.grouped)
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
        
    }
}


// MARK: - Scenarios (demo content, presented like an app)

struct ScenariosSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(DemoScenario.all) { scenario in
                        Button {
                            dismiss()
                            model.apply(scenario)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: scenario.symbol)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(scenario.title).foregroundStyle(.primary)
                                    Text(scenario.subtitle).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Each scenario opens an app on each half of the phone. Then fold.")
                }
                Section {
                    Button(role: .destructive) {
                        dismiss()
                        model.resetPanes()
                    } label: {
                        Label("Clear both halves", systemImage: "xmark.circle")
                    }
                }
            }
            .navigationTitle("Scenarios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
