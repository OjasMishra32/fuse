import SwiftUI

// MARK: - Community feed
//
// Public fuses from Supabase as tappable cards. Tapping rebuilds a `FuseResult` and hands it
// to the caller, who shows it in the normal result screen.

struct CommunityView: View {
    var onOpen: (FuseResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rows: [RemoteFuse] = []
    @State private var isLoading = false
    @State private var hasLoaded = false

    private var supabase: SupabaseService { .shared }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                content
            }
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
        
        .tint(Theme.cyan)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if !supabase.isConfigured {
            ScrollView {
                setupState
                    .padding(20)
                    .padding(.top, 24)
            }
            .scrollIndicators(.hidden)
        } else if isLoading && !hasLoaded {
            ProgressView()
                .tint(Theme.textPrimary)
                .controlSize(.large)
        } else if rows.isEmpty {
            ScrollView {
                emptyState
                    .padding(20)
                    .padding(.top, 40)
            }
            .refreshable { await load() }
            .scrollIndicators(.hidden)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(rows) { row in
                        CommunityCard(row: row) { open(row) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .refreshable { await load() }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: States

    private var setupState: some View {
        ResultCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.wave.2")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.energy)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Community isn't connected yet")
                            .font(.fuseHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Four steps, about three minutes.")
                            .font(.fuseCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SetupStep(number: 1, text: "Create a project at supabase.com.")
                    SetupStep(number: 2, text: "Run supabase/schema.sql in the SQL editor.")
                    SetupStep(number: 3, text: "Turn on Anonymous sign-ins under Authentication › Providers.")
                    SetupStep(number: 4, text: "Paste the project ref and anon key in Settings › Keys.")
                }
                Text("Public fuses from every Duo show up here, and your own fuses are saved to your anonymous account.")
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: supabase.lastError == nil ? "sparkles" : "wifi.exclamationmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.energy)
            Text(supabase.lastError == nil ? "No public fuses yet" : "Couldn't reach Supabase")
                .font(.fuseHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text(supabase.lastError ?? "Be the first: fuse something, then share it to the community from the result screen.")
                .font(.fuseCaption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            GlassButton(title: "Refresh", symbol: "arrow.clockwise") {
                Haptics.tap()
                Task { await load() }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
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

private struct CommunityCard: View {
    var row: RemoteFuse
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.energy)
                        .opacity(0.16)
                    Image(systemName: row.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.energy)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text(row.title)
                        .font(.fuseHeadline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !row.summary.isEmpty {
                        Text(row.summary)
                            .font(.fuseBody)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: 6) {
                        KindTag(kind: row.leftKind, raw: row.left_kind)
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                        KindTag(kind: row.rightKind, raw: row.right_kind)
                        Spacer(minLength: 4)
                        if let date = row.created_at {
                            Text(date, format: .relative(presentation: .named))
                                .font(.fuseCaption)
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 2)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 14)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.ink2, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct KindTag: View {
    var kind: SurfaceKind?
    var raw: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind?.symbol ?? "questionmark.square.dashed")
                .font(.system(size: 10, weight: .semibold))
            Text(kind?.title ?? (raw.isEmpty ? "Unknown" : raw.capitalized))
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(kind?.tint ?? Theme.textTertiary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background((kind?.tint ?? Theme.textTertiary).opacity(0.12), in: Capsule())
    }
}

private struct SetupStep: View {
    var number: Int
    var text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.85))
                .frame(width: 22, height: 22)
                .background(Theme.energy, in: Circle())
            Text(text)
                .font(.fuseBody)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
