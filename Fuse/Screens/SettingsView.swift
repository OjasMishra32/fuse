import SwiftUI

// MARK: - Settings
//
// A standard inset-grouped form. Each key is its own section with a footer explaining it;
// secrets are secure fields with a reveal toggle. Then service status, Fuse Pro, and a short
// note on the iPhone Duo APIs the app is built on. Keys save on commit and broadcast via
// AppConfig.didChange.

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
                ForEach(AppConfig.Key.allCases) { key in
                    keySection(key)
                }
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

    private func keySection(_ key: AppConfig.Key) -> some View {
        Section {
            HStack(spacing: 12) {
                field(for: key)
                if key.isSecret {
                    Button {
                        Haptics.selection()
                        if revealed.contains(key) { revealed.remove(key) } else { revealed.insert(key) }
                    } label: {
                        Image(systemName: revealed.contains(key) ? "eye.slash" : "eye")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(revealed.contains(key) ? "Hide \(key.title)" : "Show \(key.title)")
                }
            }
            if key == .openAIModel { modelChoices }
        } header: {
            Text(key.title)
        } footer: {
            Text(Self.explanation(for: key))
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
        .font(.system(.body, design: .monospaced))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .keyboardType(.asciiCapable)
        .submitLabel(.done)
        .focused($focusedKey, equals: key)
        .onSubmit { save(key) }
    }

    private static func explanation(for key: AppConfig.Key) -> String {
        switch key {
        case .openAIKey:
            "Used for every fuse. Stored only on this device and overrides the build-time xcconfig."
        case .openAIModel:
            "The model that reads both screens. Leave empty for the default."
        case .supabaseProjectRef:
            "The short ref from your project's URL. Enables the community feed and cloud history."
        case .supabaseAnonKey:
            "The public anon key from Project Settings, API. Never the service role key."
        case .revenueCatKey:
            "Public SDK key for Fuse Pro subscriptions. Without it the paywall runs in demo mode."
        }
    }

    private var currentModel: String {
        let typed = (values[.openAIModel] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? AppConfig.openAIModel : typed
    }

    /// Quick picks for the model, as bordered capsules; the selected one is prominent.
    private var modelChoices: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Self.modelChoices, id: \.self) { model in
                    let selected = currentModel == model
                    Button {
                        Haptics.selection()
                        values[.openAIModel] = model
                        save(.openAIModel)
                    } label: {
                        Text(model)
                            .font(.footnote.weight(.medium))
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(selected ? Color.accentColor : Color(uiColor: .secondaryLabel))
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    // MARK: Status

    private var statusSection: some View {
        Section {
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
        } header: {
            Text("Status")
        } footer: {
            Text("A green dot means the service is configured and reachable.")
        }
    }

    // MARK: Fuse Pro

    private var proSection: some View {
        let store = RevenueCatService.shared
        return Section {
            HStack(spacing: 12) {
                IconTile(symbol: "bolt.fill", tint: .accentColor, size: 30)
                Text("Fuse Pro")
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                planBadge(isPro: store.isPro, remaining: store.remainingFree)
            }
            .frame(minHeight: 44)

            Button {
                Haptics.tap()
                Task { await store.restore() }
            } label: {
                HStack {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                    Spacer()
                    if store.isRestoring { ProgressView().controlSize(.small) }
                }
            }
            .disabled(store.isRestoring)

            Button {
                Haptics.tap()
                showPaywall = true
            } label: {
                Label("Show Paywall", systemImage: "sparkles")
            }

            if store.demoPro {
                Button(role: .destructive) {
                    Haptics.tap()
                    store.resetDemo()
                } label: {
                    Label("Reset Demo Pro", systemImage: "arrow.uturn.backward")
                }
            }

            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Fuse Pro")
        } footer: {
            Text(store.isConfigured
                 ? "Subscriptions are handled by RevenueCat. Entitlement: \"\(RevenueCatService.entitlementID)\"."
                 : "No RevenueCat key yet. The paywall runs in demo mode and unlocks Pro on this device only.")
        }
    }

    @ViewBuilder
    private func planBadge(isPro: Bool, remaining: Int) -> some View {
        if isPro {
            Text("Pro")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor, in: Capsule())
        } else {
            Text("\(remaining) left today")
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
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

/// Service name and one-line status, with a coloured dot on the trailing edge.
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
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Circle()
                .fill(ok ? Color(uiColor: .systemGreen) : Color(uiColor: .tertiaryLabel))
                .frame(width: 10, height: 10)
                .animation(Theme.smooth, value: ok)
                .accessibilityLabel(ok ? "Configured" : "Not configured")
        }
        .padding(.vertical, 2)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

/// A Duo API on an accent tile, with the API name in monospace and a one-line explanation.
private struct AboutRow: View {
    var symbol: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: symbol, tint: .accentColor, size: 30)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
