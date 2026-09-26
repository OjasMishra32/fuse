import SwiftUI

// MARK: - History
//
// Newest first. Tap a row to reopen the result; swipe to delete; Clear wipes everything.
// Presented by the app in a sheet.

struct HistoryView: View {
    var onOpen: (FuseResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    private var store: HistoryStore { HistoryStore.shared }

    var body: some View {
        NavigationStack {
            Group {
                if store.items.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background { Theme.background }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.items.isEmpty {
                        Button("Clear", role: .destructive) { confirmClear = true }
                            .tint(ResultPalette.bad)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog("Clear all history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear \(store.items.count) \(store.items.count == 1 ? "result" : "results")", role: .destructive) {
                    Haptics.medium()
                    withAnimation(Theme.snappy) { store.clear() }
                }
            } message: {
                Text("Past results and their images will be removed from this device.")
            }
        }
        
        .tint(Theme.violet)
    }

    private var list: some View {
        List {
            ForEach(store.items) { item in
                Button {
                    Haptics.tap()
                    onOpen(item)
                } label: {
                    HistoryRow(item: item)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Theme.line)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 16))
            }
            .onDelete { offsets in
                let doomed = offsets.compactMap { store.items[safe: $0] }
                Haptics.soft()
                withAnimation(Theme.snappy) {
                    doomed.forEach { store.remove($0) }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text("No fuses yet")
                .font(.fuseHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text("Fold the phone with something on each screen. Results you make will collect here.")
                .font(.fuseCaption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct HistoryRow: View {
    let item: FuseResult

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.dateTimeStyle = .named
        return f
    }()

    private var relativeDate: String {
        let interval = Date().timeIntervalSince(item.createdAt)
        if interval < 60 { return "now" }
        return Self.relative.localizedString(for: item.createdAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Theme.ink3)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
                Image(systemName: item.artifact.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.violet)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.fuseHeadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                inputsLine
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(relativeDate)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var inputsLine: some View {
        if item.inputs.isEmpty {
            Text(item.recipe.fuseHumanized)
                .font(.fuseCaption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        } else {
            HStack(spacing: 5) {
                ForEach(Array(item.inputs.prefix(3).enumerated()), id: \.offset) { index, input in
                    if index > 0 {
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Image(systemName: input.kind.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(input.kind.tint)
                    Text(input.title.isEmpty ? input.kind.title : input.title)
                        .font(.fuseCaption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .layoutPriority(index == 0 ? 1 : 0)
                }
            }
        }
    }
}
