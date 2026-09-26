import SwiftUI
import UIKit

// MARK: - Result screen
//
// The payoff. Quiet header (recipe, the two inputs, title, summary), then the artifact,
// then follow-ups and actions. Everything fades in, staggered, once.

struct ResultView: View {
    let result: FuseResult
    var compact: Bool = false
    var onFollowUp: (String) -> Void
    var onDismiss: () -> Void
    var onRefuse: () -> Void

    @State private var appeared = false
    @State private var showShare = false
    @State private var copied = false

    private var gutter: CGFloat { compact ? 16 : 24 }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: compact ? 18 : 24) {
                header
                    .reveal(appeared, index: 0)
                artifact
                    .reveal(appeared, index: 1)
                if !result.followUps.isEmpty {
                    followUps
                        .reveal(appeared, index: 2)
                }
                actions
                    .reveal(appeared, index: 3)
            }
            .padding(.horizontal, gutter)
            .padding(.top, compact ? 12 : 18)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { Theme.background }
        .environment(\.fuseCompact, compact)
        .onAppear {
            guard !appeared else { return }
            appeared = true
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [result.plainText])
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            HStack(alignment: .center, spacing: 10) {
                RecipeCapsule(title: result.recipe.fuseHumanized, symbol: result.artifact.symbol)
                Spacer(minLength: 8)
                GlassIconButton(symbol: "xmark", size: 32, tint: Theme.textSecondary) {
                    Haptics.tap()
                    onDismiss()
                }
            }

            if !result.inputs.isEmpty {
                inputsRow
            }

            Text(result.title)
                .font(compact ? .system(size: 24, weight: .bold) : .fuseTitle)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            if !result.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(result.summary)
                    .font(.fuseBody)
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var inputsRow: some View {
        FlowLayout(spacing: 6, rowSpacing: 6) {
            ForEach(Array(result.inputs.enumerated()), id: \.offset) { index, input in
                if index > 0 {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 14, height: 27)
                }
                InputChip(input: input)
            }
        }
    }

    // MARK: Artifact

    @ViewBuilder
    private var artifact: some View {
        switch result.artifact {
        case .markdown(let markdown):
            MarkdownArtifactView(markdown: markdown)
        case .itinerary(let itinerary):
            ItineraryArtifactView(itinerary: itinerary)
        case .event(let event):
            EventArtifactView(event: event)
        case .email(let email):
            EmailArtifactView(email: email)
        case .quiz(let quiz):
            QuizArtifactView(quiz: quiz)
        case .slides(let deck):
            SlidesArtifactView(deck: deck)
        case .code(let code):
            CodeArtifactView(code: code)
        case .diff(let diff):
            DiffArtifactView(diff: diff)
        case .checklist(let checklist):
            ChecklistArtifactView(checklist: checklist)
        case .table(let table):
            TableArtifactView(table: table)
        case .grade(let report):
            GradeArtifactView(report: report)
        case .image(let image):
            ImageArtifactView(image: image)
        }
    }

    // MARK: Follow-ups

    private var followUps: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Next")
            FlowLayout(spacing: 8) {
                ForEach(Array(result.followUps.enumerated()), id: \.offset) { _, suggestion in
                    Chip(title: suggestion, symbol: "arrow.turn.down.right", tint: Theme.textPrimary) {
                        Haptics.tap()
                        onFollowUp(suggestion)
                    }
                }
            }
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Hairline()
            FlowLayout(spacing: 10, rowSpacing: 10) {
                EnergyButton(title: "Fuse again", symbol: "sparkles") {
                    Haptics.medium()
                    onRefuse()
                }
                GlassButton(title: "Share", symbol: "square.and.arrow.up") {
                    Haptics.tap()
                    showShare = true
                }
                GlassButton(title: copied ? "Copied" : "Copy", symbol: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = result.plainText
                    Haptics.soft()
                    withAnimation(Theme.snappy) { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.4))
                        withAnimation(Theme.snappy) { copied = false }
                    }
                }
                GlassButton(title: "Close", symbol: "xmark") {
                    Haptics.tap()
                    onDismiss()
                }
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Header pieces

private struct RecipeCapsule: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.fuseCaption)
                .lineLimit(1)
        }
        .foregroundStyle(Theme.violet)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.violet.opacity(0.14)))
        .overlay(Capsule().stroke(Theme.violet.opacity(0.28), lineWidth: 1))
    }
}

private struct InputChip: View {
    let input: InputSummary

    private var detail: String? {
        let t = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.caseInsensitiveCompare(input.kind.title) != .orderedSame else { return nil }
        return t
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: input.kind.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(input.kind.tint)
            Text(input.kind.title)
                .font(.fuseCaption)
                .foregroundStyle(Theme.textPrimary)
            if let detail {
                Text("·")
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textTertiary)
                Text(detail)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.06)))
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }
}

// MARK: - Plain-text rendering (Share / Copy)

extension FuseResult {
    /// A faithful plain-text version of the whole result, used by Share and Copy.
    var plainText: String {
        var out: [String] = []
        out.append(title)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSummary.isEmpty { out.append(trimmedSummary) }
        if !inputs.isEmpty {
            out.append("Fused from: " + inputs.map { input in
                input.title.isEmpty ? input.kind.title : "\(input.kind.title) — \(input.title)"
            }.joined(separator: " + "))
        }
        out.append("")
        out.append(artifact.plainText)
        if !followUps.isEmpty {
            out.append("")
            out.append("Next:")
            out.append(contentsOf: followUps.map { "• \($0)" })
        }
        out.append("")
        out.append("— Made with Fuse")
        return out.joined(separator: "\n")
    }
}

extension FuseArtifact {
    var plainText: String {
        switch self {
        case .markdown(let markdown):
            return markdown

        case .itinerary(let it):
            var lines: [String] = [it.destination]
            var number = 0
            for day in it.days {
                lines.append("")
                lines.append(day.title)
                for stop in day.stops {
                    number += 1
                    var line = "\(number). "
                    if let time = stop.time, !time.isEmpty { line += "\(time) — " }
                    line += stop.name
                    lines.append(line)
                    if let note = stop.note, !note.isEmpty { lines.append("   \(note)") }
                }
            }
            if !it.tips.isEmpty {
                lines.append("")
                lines.append("Tips:")
                lines.append(contentsOf: it.tips.map { "• \($0)" })
            }
            return lines.joined(separator: "\n")

        case .event(let e):
            var lines: [String] = [e.title]
            if let start = e.startDate {
                if e.allDay {
                    lines.append("All day · " + start.formatted(date: .complete, time: .omitted))
                } else if let end = e.endDate, end > start {
                    lines.append((start..<end).formatted(date: .abbreviated, time: .shortened))
                } else {
                    lines.append(start.formatted(date: .abbreviated, time: .shortened))
                }
            } else if !e.start.isEmpty {
                lines.append([e.start, e.end ?? ""].filter { !$0.isEmpty }.joined(separator: " – "))
            }
            if let location = e.location, !location.isEmpty { lines.append("Where: \(location)") }
            if !e.attendees.isEmpty { lines.append("With: " + e.attendees.joined(separator: ", ")) }
            if let notes = e.notes, !notes.isEmpty { lines.append(""); lines.append(notes) }
            return lines.joined(separator: "\n")

        case .email(let m):
            var lines: [String] = []
            if !m.to.isEmpty { lines.append("To: " + m.to.joined(separator: ", ")) }
            if !m.subject.isEmpty { lines.append("Subject: " + m.subject) }
            if !lines.isEmpty { lines.append("") }
            lines.append(m.body)
            return lines.joined(separator: "\n")

        case .quiz(let q):
            var lines: [String] = [q.title]
            let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            for (i, question) in q.questions.enumerated() {
                lines.append("")
                lines.append("\(i + 1). \(question.prompt)")
                for (c, choice) in question.choices.enumerated() {
                    let letter = c < letters.count ? String(letters[c]) : "\(c + 1)"
                    lines.append("   \(letter)) \(choice)")
                }
                if question.choices.indices.contains(question.answerIndex) {
                    let letter = question.answerIndex < letters.count ? String(letters[question.answerIndex]) : "\(question.answerIndex + 1)"
                    lines.append("   Answer: \(letter)")
                }
                if let explanation = question.explanation, !explanation.isEmpty {
                    lines.append("   \(explanation)")
                }
            }
            return lines.joined(separator: "\n")

        case .slides(let deck):
            var lines: [String] = [deck.title]
            for (i, slide) in deck.slides.enumerated() {
                lines.append("")
                lines.append("Slide \(i + 1): \(slide.title)")
                lines.append(contentsOf: slide.bullets.map { "• \($0)" })
                if let notes = slide.notes, !notes.isEmpty { lines.append("Notes: \(notes)") }
            }
            return lines.joined(separator: "\n")

        case .code(let c):
            var lines: [String] = []
            if let filename = c.filename, !filename.isEmpty {
                lines.append("\(filename) (\(c.language))")
            } else {
                lines.append(c.language)
            }
            lines.append("")
            lines.append(c.code)
            if let explanation = c.explanation, !explanation.isEmpty {
                lines.append("")
                lines.append(explanation)
            }
            return lines.joined(separator: "\n")

        case .diff(let d):
            var lines: [String] = [d.title]
            for change in d.changes {
                lines.append("")
                lines.append("− \(change.original)")
                lines.append("+ \(change.revised)")
                if let reason = change.reason, !reason.isEmpty { lines.append("  \(reason)") }
            }
            if let verdict = d.verdict, !verdict.isEmpty {
                lines.append("")
                lines.append("Verdict: \(verdict)")
            }
            return lines.joined(separator: "\n")

        case .checklist(let list):
            var lines: [String] = [list.title]
            for item in list.items {
                var line = "☐ \(item.text)"
                if let detail = item.detail, !detail.isEmpty { line += " — \(detail)" }
                lines.append(line)
            }
            return lines.joined(separator: "\n")

        case .table(let t):
            var lines: [String] = []
            if !t.title.isEmpty { lines.append(t.title); lines.append("") }
            if !t.columns.isEmpty {
                lines.append(t.columns.joined(separator: " | "))
                lines.append(t.columns.map { String(repeating: "-", count: max($0.count, 3)) }.joined(separator: " | "))
            }
            lines.append(contentsOf: t.rows.map { $0.joined(separator: " | ") })
            if let note = t.note, !note.isEmpty { lines.append(""); lines.append(note) }
            return lines.joined(separator: "\n")

        case .grade(let g):
            var lines: [String] = ["Score: \(g.score.isEmpty ? "—" : g.score)"]
            for item in g.items {
                var line = "\(item.correct ? "✓" : "✗") \(item.question)"
                if !item.yourAnswer.isEmpty { line += " — your answer: \(item.yourAnswer)" }
                lines.append(line)
                if let feedback = item.feedback, !feedback.isEmpty { lines.append("   \(feedback)") }
            }
            if !g.weaknesses.isEmpty {
                lines.append("")
                lines.append("Weak spots: " + g.weaknesses.joined(separator: ", "))
            }
            if !g.nextSteps.isEmpty {
                lines.append("")
                lines.append("Next steps:")
                lines.append(contentsOf: g.nextSteps.map { "☐ \($0)" })
            }
            return lines.joined(separator: "\n")

        case .image(let img):
            var lines: [String] = []
            if let caption = img.caption, !caption.isEmpty { lines.append(caption) }
            if !img.prompt.isEmpty { lines.append("Prompt: \(img.prompt)") }
            if lines.isEmpty { lines.append("Generated image") }
            return lines.joined(separator: "\n")
        }
    }
}
