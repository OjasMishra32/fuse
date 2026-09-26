import SwiftUI

// MARK: - Community feed
//
// Public fuses from Supabase as a plain inset-grouped list. Tapping rebuilds a `FuseResult`
// and hands it to the caller, who shows it in the normal result screen.

struct CommunityView: View {
    var onOpen: (FuseResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rows: [RemoteFuse] = []
    @State private var isLoading = false
    @State private var hasLoaded = false

    private var supabase: SupabaseService { .shared }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Community")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            Haptics.tap()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if !supabase.isConfigured {
            List {
                setupSection
            }
            .listStyle(.insetGrouped)
        } else if isLoading && !hasLoaded {
            ProgressView()
                .controlSize(.large)
        } else if rows.isEmpty {
            // Wrapped in a scroll view so pull-to-refresh works on the empty state too.
            ScrollView {
                emptyState
                    .containerRelativeFrame(.vertical)
            }
            .refreshable { await load() }
        } else {
            List {
                Section {
                    ForEach(rows) { row in
                        Button {
                            open(row)
                        } label: {
                            FuseResultRow(title: row.title, subtitle: inputsLine(row), date: row.created_at)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading) {
                            ShareLink(item: row.toFuseResult().plainText) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(.accentColor)
                        }
                    }
                } footer: {
                    Text("Public fuses from every Duo. Share your own from the result screen.")
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await load() }
        }
    }

    private func inputsLine(_ row: RemoteFuse) -> String {
        let left = row.leftKind?.title ?? (row.left_kind.isEmpty ? "Unknown" : row.left_kind.capitalized)
        let right = row.rightKind?.title ?? (row.right_kind.isEmpty ? "Unknown" : row.right_kind.capitalized)
        return "\(left) and \(right)"
    }

    // MARK: States

    private var setupSection: some View {
        Section {
            SetupStep(number: 1, text: "Create a project at supabase.com.")
            SetupStep(number: 2, text: "Run supabase/schema.sql in the SQL editor.")
            SetupStep(number: 3, text: "Turn on Anonymous sign-ins under Authentication, Providers.")
            SetupStep(number: 4, text: "Paste the project ref and anon key in Settings, Keys.")
        } header: {
            Text("Community isn't connected yet")
        } footer: {
            Text("Four steps, about three minutes. Public fuses from every Duo show up here, and your own fuses are saved to your anonymous account.")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(supabase.lastError == nil ? "No public fuses yet" : "Couldn't reach Supabase",
                  systemImage: supabase.lastError == nil ? "person.2" : "wifi.exclamationmark")
        } description: {
            Text(supabase.lastError ?? "Be the first: fuse something, then share it to the community from the result screen.")
        } actions: {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Haptics.tap()
                Task { await load() }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
    }

    // MARK: Actions

    private func load() async {
        guard supabase.isConfigured, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        rows = await supabase.fetchCommunity(limit: 30)
        hasLoaded = true
    }

    private func open(_ row: RemoteFuse) {
        Haptics.medium()
        onOpen(row.toFuseResult())
        dismiss()
    }
}

// MARK: - Pieces

private struct SetupStep: View {
    var number: Int
    var text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
