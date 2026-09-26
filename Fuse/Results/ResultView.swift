import SwiftUI
import UIKit

// MARK: - Result screen
//
// The payoff. Quiet header (orb glyph, the two inputs, Close), a large title and the summary,
// then the artifact, then follow-ups as grouped rows. Actions live in a glass toolbar pinned to
// the bottom safe area so they never cover content. Everything fades in, staggered, once.

struct ResultView: View {
    let result: FuseResult
    var compact: Bool = false
    /// The inner display supplies its own Back button; the cover shows Close in the header.
    var showsClose: Bool = true
    var onFollowUp: (String) -> Void
    var onDismiss: () -> Void
    var onRefuse: () -> Void

    @State private var appeared = false
    @State private var showShare = false
    @State private var copied = false

    /// 20pt on the inner display, 16pt on the cover.
    private var gutter: CGFloat { compact ? Theme.margin : Theme.gutter }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                // Four staggered steps: header, artifact, follow-ups, then the toolbar below. The
                // width is pinned to the display so wide artifacts wrap instead of pushing the
                // page sideways.
                VStack(alignment: .leading, spacing: 24) {
                    header
                        .reveal(appeared, index: 0)
                    artifact
                        .reveal(appeared, index: 1)
                    if !result.followUps.isEmpty {
                        followUps
                            .reveal(appeared, index: 2)
                    }
                }
                .padding(.horizontal, gutter)
                .padding(.top, compact ? 12 : 16)
                .padding(.bottom, 24)
                .frame(width: max(proxy.size.width, 0), alignment: .leading)
                .clipped()
            }
        }
        .safeAreaInset(edge: .bottom) {
            actions
                .reveal(appeared, index: 3)
        }
        .background { Theme.grouped.ignoresSafeArea() }
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
        VStack(alignment: .leading, spacing: 8) {
            // Orb glyph, the inputs, and Close, on one quiet line above the title.
            HStack(spacing: 12) {
                OrbGlyph(size: 28)
                Text(result.inputsLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if showsClose {
                    Button {
                        Haptics.tap()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Close")
                }
            }
            .frame(minHeight: 30)

            Text(result.title)
                .font(compact ? .title.bold() : .largeTitle.bold())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !result.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(result.summary)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
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
        case .openLate(let plan):
            OpenLateArtifactView(plan: plan)
        }
    }

    // MARK: Follow-ups

    private var followUps: some View {
        ResultSection(title: "Next") {
            ResultCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(result.followUps.enumerated()), id: \.offset) { index, suggestion in
                        if index > 0 { Hairline().padding(.leading, Theme.margin) }
                        Button {
                            Haptics.tap()
                            onFollowUp(suggestion)
                        } label: {
                            HStack(spacing: 12) {
                                Text(suggestion)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, Theme.margin)
                            .padding(.vertical, 12)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            }
        }
    }

    // MARK: Actions (bottom toolbar)

    /// Pinned to the bottom edge as glass buttons; content scrolls beneath it.
    private var actions: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    Haptics.medium()
                    onRefuse()
                } label: {
                    Label("Fuse again", systemImage: "arrow.clockwise")
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)

                Button {
                    Haptics.tap()
                    showShare = true
                } label: {
                    toolbarLabel("Share", symbol: "square.and.arrow.up")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .accessibilityLabel("Share")

                Button {
                    UIPasteboard.general.string = result.plainText
                    Haptics.soft()
                    withAnimation(Theme.snappy) { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.4))
                        withAnimation(Theme.snappy) { copied = false }
                    }
                } label: {
                    toolbarLabel(copied ? "Copied" : "Copy", symbol: copied ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .accessibilityLabel(copied ? "Copied" : "Copy")
            }
            .controlSize(.regular)
        }
        .padding(.horizontal, gutter)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    /// Icon only on the narrow cover, icon and title on the inner display.
    @ViewBuilder
    private func toolbarLabel(_ title: String, symbol: String) -> some View {
        if compact {
            Image(systemName: symbol)
                .frame(minWidth: 20)
        } else {
            Label(title, systemImage: symbol)
        }
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

        case .openLate(let plan):
            return plan.lines.joined(separator: "\n")
        }
    }
}
