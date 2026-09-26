import SwiftUI

// MARK: - History
//
// Newest first. Tap a row to reopen the result; swipe to share or delete; Clear wipes everything.
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
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.items.isEmpty {
                        Button("Clear", role: .destructive) { confirmClear = true }
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
    }

    private var list: some View {
        List {
            Section {
                ForEach(store.items) { item in
                    Button {
                        Haptics.tap()
                        onOpen(item)
                    } label: {
                        FuseResultRow(title: item.title, subtitle: item.inputsLine, date: item.createdAt)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Haptics.soft()
                            withAnimation(Theme.snappy) { store.remove(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        ShareLink(item: item.plainText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.accentColor)
                    }
                }
            } footer: {
                Text("Results are kept on this device only.")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No fuses yet", systemImage: "clock.arrow.circlepath")
        } description: {
            Text("Fold the phone with something on each screen. Results you make will collect here.")
        }
    }
}

// MARK: - Row

/// One fuse result in a list: static orb glyph, title, the inputs, and how long ago.
/// Shared by History and Community.
struct FuseResultRow: View {
    var title: String
    var subtitle: String
    var date: Date?

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.dateTimeStyle = .named
        return f
    }()

    private var relativeDate: String? {
        guard let date else { return nil }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        return Self.relative.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            OrbGlyph(size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let relativeDate {
                Text(relativeDate)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
