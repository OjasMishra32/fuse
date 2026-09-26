import SwiftUI

// MARK: - Native result card
//
// Rendered by iOS inside the system snippet when "Fuse Screens" completes. Compact, system
// colors only, no buttons (snippet buttons need a SnippetIntent, which comes later). Rendering
// reads the result only; it never starts a model call.

struct FuseSnippetView: View {
    let result: FuseResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: result.artifact.symbol)
                    .foregroundStyle(.secondary)
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)
            }

            let summary = result.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            if case .image(let artifact) = result.artifact {
                if let image = artifact.uiImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel(artifact.caption ?? result.title)
                } else {
                    Text("The generated image could not be displayed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            let rows = Self.rows(for: result.artifact)
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Text(row)
                            .font(.footnote)
                            .lineLimit(2)
                    }
                }
                .padding(.top, 2)
            }

            Text("Fused from two screens")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    // MARK: Compact artifact rows

    /// At most a few plain-text lines of the key facts; markdown shows its first five lines.
    static func rows(for artifact: FuseArtifact, limit: Int = 4) -> [String] {
        switch artifact {
        case .image:
            // Display the generated pixels above instead of exposing the image-edit prompt.
            return []

        case .markdown(let md):
            return md
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .prefix(5)
                .map { $0 }

        case .checklist(let list):
            return list.items.prefix(limit).map { "• \($0.text)" }

        case .itinerary(let it):
            var out: [String] = []
            for day in it.days {
                for stop in day.stops {
                    if let t = stop.time, !t.isEmpty { out.append("\(t) — \(stop.name)") } else { out.append("• \(stop.name)") }
                    if out.count == limit { return out }
                }
            }
            if out.isEmpty { out.append(it.destination) }
            return out

        case .table(let table):
            var out: [String] = []
            if !table.columns.isEmpty { out.append(table.columns.joined(separator: " · ")) }
            for row in table.rows {
                out.append(row.joined(separator: " · "))
                if out.count == limit { break }
            }
            return out

        case .event(let e):
            var out: [String] = [e.title]
            if !e.start.isEmpty { out.append(e.allDay ? "All day, \(e.start)" : e.start) }
            if let loc = e.location, !loc.isEmpty { out.append(loc) }
            if let notes = e.notes, !notes.isEmpty { out.append(notes) }
            return Array(out.prefix(limit))

        case .email(let mail):
            var out: [String] = []
            if !mail.to.isEmpty { out.append("To: \(mail.to.joined(separator: ", "))") }
            if !mail.subject.isEmpty { out.append("Subject: \(mail.subject)") }
            if let firstLine = mail.body.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                out.append(firstLine)
            }
            return Array(out.prefix(limit))

        default:
            return artifact.plainText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .prefix(limit)
                .map { $0 }
        }
    }
}
