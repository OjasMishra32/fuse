import SwiftUI

// MARK: - Settings
//
// Keys (saved on commit, broadcast via AppConfig.didChange), sponsor status, Fuse Pro and
// a short note on the iPhone Duo APIs the app is built on.

struct SettingsView: View {
    var onDismiss: () -> Void

    @State private var values: [AppConfig.Key: String] = [:]
    @State private var revealed: Set<AppConfig.Key> = []
    @State private var showPaywall = false
    @FocusState private var focusedKey: AppConfig.Key?

    private static let modelChoices = ["gpt-6-sol", "gpt-6-astra", "gpt-5.5", "gpt-4.1"]

    var body: some View {
        NavigationStack {
            List {
                keysSection
                statusSection
                proSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.tap()
                        saveAll()
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: focusedKey) { previous, _ in
            if let previous { save(previous) }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
        }
    }

    // MARK: Keys

    private var keysSection: some View {
        Section {
            ForEach(AppConfig.Key.allCases) { key in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(key.title)
                            .font(.fuseCaption)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        if key.isSecret {
                            Button {
                                Haptics.selection()
                                if revealed.contains(key) { revealed.remove(key) } else { revealed.insert(key) }
                            } label: {
                                Image(systemName: revealed.contains(key) ? "eye.slash" : "eye")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    field(for: key)
                    if key == .openAIModel { modelChips }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Keys")
        } footer: {
            Text("Stored only on this device. Values here override the build-time xcconfig.")
        }
    }

    @ViewBuilder
    private func field(for key: AppConfig.Key) -> some View {
        let binding = Binding(
            get: { values[key] ?? "" },
            set: { values[key] = $0 }
        )
        Group {
            if key.isSecret && !revealed.contains(key) {
                SecureField(key.placeholder, text: binding)
            } else {
                TextField(key.placeholder, text: binding)
            }
        }
        .font(.fuseMono)
        .foregroundStyle(Theme.textPrimary)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .keyboardType(.asciiCapable)
        .submitLabel(.done)
        .focused($focusedKey, equals: key)
        .onSubmit { save(key) }
    }

    private var currentModel: String {
        let typed = (values[.openAIModel] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? AppConfig.openAIModel : typed
    }

    private var modelChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Self.modelChoices, id: \.self) { model in
                    Chip(title: model, symbol: "cpu", tint: Theme.cyan, selected: currentModel == model) {
                        Haptics.selection()
                        values[.openAIModel] = model
                        save(.openAIModel)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Status

    private var statusSection: some View {
        Section("Status") {
            StatusRow(
                name: "OpenAI",
                symbol: "brain",
                ok: AppConfig.hasOpenAI,
                detail: AppConfig.hasOpenAI ? "Ready · \(AppConfig.openAIModel)" : "Add an API key to fuse"
            )
            StatusRow(
                name: "Supabase",
                symbol: "cylinder.split.1x2",
                ok: SupabaseService.shared.isConfigured,
                detail: SupabaseService.shared.status
            )
            StatusRow(
                name: "RevenueCat",
                symbol: "creditcard",
                ok: RevenueCatService.shared.isConfigured,
                detail: RevenueCatService.shared.statusText
            )
        }
    }

    // MARK: Fuse Pro

    private var proSection: some View {
        let store = RevenueCatService.shared
        return Section {
            HStack {
                Label("Fuse Pro", systemImage: "bolt.fill")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(store.isPro ? "PRO" : "FREE · \(store.remainingFree) LEFT TODAY")
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(store.isPro ? Color.white : Theme.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background {
                        if store.isPro {
                            Capsule().fill(Color.accentColor)
                        } else {
                            Capsule().fill(Color(uiColor: .tertiarySystemFill))
                        }
                    }
            }

            Button {
                Haptics.tap()
                Task { await store.restore() }
            } label: {
                HStack {
                    Label("Restore purchases", systemImage: "arrow.clockwise")
                    Spacer()
                    if store.isRestoring { ProgressView().controlSize(.small) }
                }
            }
            .disabled(store.isRestoring)

            Button {
                Haptics.tap()
                showPaywall = true
            } label: {
                Label("Show paywall", systemImage: "sparkles")
            }

            if store.demoPro {
                Button(role: .destructive) {
                    Haptics.tap()
                    store.resetDemo()
                } label: {
                    Label("Reset demo Pro", systemImage: "arrow.uturn.backward")
                }
            }

            if let error = store.lastError {
                Text(error)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.magenta)
            }
        } header: {
            Text("Fuse Pro")
        } footer: {
            Text(store.isConfigured
                 ? "Subscriptions are handled by RevenueCat. Entitlement: \"\(RevenueCatService.entitlementID)\"."
                 : "No RevenueCat key yet. The paywall runs in demo mode and unlocks Pro on this device only.")
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            AboutRow(symbol: "iphone.gen3", title: "onHingeChange",
                     detail: "SwiftUI modifier that fires as the Duo folds. The fold itself is the fuse trigger.")
            AboutRow(symbol: "rectangle.split.2x1", title: "DeviceHinge",
                     detail: "Hinge state and angle, driving the melt animation across the seam.")
            AboutRow(symbol: "rectangle.center.inset.filled", title: "reservedRegions(.division)",
                     detail: "Layout API that keeps content off the seam so both halves stay legible.")
            AboutRow(symbol: "wand.and.stars", title: "App Intents",
                     detail: "Siri and Shortcuts can seed either screen and start a fuse hands-free.")
        } header: {
            Text("About")
        } footer: {
            Text("Made at Bitrig Hacks, iPhone Duo Edition. Fuse \(Self.appVersion)")
        }
    }

    private static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }

    // MARK: Persistence

    private func load() {
        for key in AppConfig.Key.allCases {
            values[key] = AppConfig.value(for: key)
        }
    }

    private func save(_ key: AppConfig.Key) {
        let newValue = (values[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard newValue != AppConfig.value(for: key) else { return }
        AppConfig.set(newValue, for: key)
        NotificationCenter.default.post(name: AppConfig.didChange, object: nil)
    }

    private func saveAll() {
        for key in AppConfig.Key.allCases { save(key) }
    }
}

// MARK: - Rows

private struct StatusRow: View {
    var name: String
    var symbol: String
    var ok: Bool
    var detail: String

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, tint: Color(uiColor: .systemGray), size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.fuseBody)
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Circle()
                .fill(ok ? Color(uiColor: .systemGreen) : Theme.textTertiary)
                .frame(width: 9, height: 9)
        }
        .padding(.vertical, 2)
    }
}

private struct AboutRow: View {
    var symbol: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: symbol, tint: .accentColor, size: 30)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.fuseMono)
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
