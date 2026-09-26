import SwiftUI
import UIKit

// MARK: - Email

struct EmailArtifactView: View {
    let email: EmailDraft
    @State private var mailUnavailable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // To / Subject as grouped rows.
            ResultCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    fieldRow("To", email.to.isEmpty ? "—" : email.to.joined(separator: ", "))
                    Hairline().padding(.leading, Theme.margin)
                    fieldRow("Subject", email.subject.isEmpty ? "No subject" : email.subject)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            }

            // The body on its own card.
            ResultCard {
                Text(email.body.isEmpty ? "Empty message" : email.body)
                    .font(.body)
                    .foregroundStyle(email.body.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FlowLayout(spacing: 8) {
                Button {
                    openMail()
                } label: {
                    Label("Open in Mail", systemImage: "envelope")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                CopyButton(text: plainBody)
            }

            if mailUnavailable {
                Text("Mail isn't set up on this device. The draft was copied instead.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var plainBody: String {
        var lines: [String] = []
        if !email.to.isEmpty { lines.append("To: " + email.to.joined(separator: ", ")) }
        if !email.subject.isEmpty { lines.append("Subject: " + email.subject) }
        if !lines.isEmpty { lines.append("") }
        lines.append(email.body)
        return lines.joined(separator: "\n")
    }

    private func fieldRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.margin)
        .padding(.vertical, 11)
        .frame(minHeight: 44)
    }

    private var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email.to.joined(separator: ",")
        var items: [URLQueryItem] = []
        if !email.subject.isEmpty { items.append(URLQueryItem(name: "subject", value: email.subject)) }
        if !email.body.isEmpty { items.append(URLQueryItem(name: "body", value: email.body)) }
        components.queryItems = items.isEmpty ? nil : items
        return components.url
    }

    private func openMail() {
        Haptics.tap()
        guard let url = mailtoURL else {
            fallbackCopy()
            return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
            if !opened { fallbackCopy() }
        }
    }

    private func fallbackCopy() {
        UIPasteboard.general.string = plainBody
        withAnimation(Theme.snappy) { mailUnavailable = true }
    }
}

// MARK: - Code

struct CodeArtifactView: View {
    let code: CodeArtifact
    private static let maxLines = 400

    private var lines: [String] {
        code.code
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\t", with: "    ")
            .components(separatedBy: "\n")
    }

    var body: some View {
        let allLines = lines
        let shown = Array(allLines.prefix(Self.maxLines))
        let hidden = allLines.count - shown.count

        VStack(alignment: .leading, spacing: 12) {
            ResultCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(code.filename?.isEmpty == false ? code.filename! : code.language)
                            .font(.fuseMono)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 8)
                        if code.filename?.isEmpty == false {
                            Text(code.language.uppercased())
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        CopyButton(text: code.code, size: .small)
                    }
                    .padding(.horizontal, Theme.margin)
                    .padding(.vertical, 8)
                    Hairline()

                    // Line numbers in the tertiary colour; the grid sizes the gutter to the widest number.
                    ScrollView(.horizontal, showsIndicators: false) {
                        Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 0) {
                            ForEach(shown.indices, id: \.self) { i in
                                GridRow {
                                    Text("\(i + 1)")
                                        .font(.fuseMono.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                        .gridColumnAlignment(.trailing)
                                    Text(shown[i].isEmpty ? " " : shown[i])
                                        .font(.fuseMono)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .padding(.vertical, 1.5)
                            }
                        }
                        .padding(Theme.margin)
                        .textSelection(.enabled)
                    }

                    if hidden > 0 {
                        Hairline()
                        Text("\(hidden) more \(hidden == 1 ? "line" : "lines"). Copy to get everything.")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Theme.margin)
                            .padding(.vertical, 8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            }

            if let explanation = code.explanation?.trimmingCharacters(in: .whitespacesAndNewlines), !explanation.isEmpty {
                InlineText(text: explanation, font: .subheadline, color: .secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Diff / redline

struct DiffArtifactView: View {
    let diff: RedlineDiff

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(diff.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(diff.changes.count == 1 ? "1 change" : "\(diff.changes.count) changes")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)

            if diff.changes.isEmpty {
                EmptyArtifactCard(text: "No changes suggested.")
            }

            ForEach(diff.changes.indices, id: \.self) { index in
                let change = diff.changes[index]
                ResultCard(padding: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        block(symbol: "minus", text: change.original, tint: ResultPalette.bad, strike: true)
                        Hairline()
                        block(symbol: "plus", text: change.revised, tint: ResultPalette.good, strike: false)
                        if let reason = change.reason?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty {
                            Hairline()
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: "text.bubble")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                InlineText(text: reason, font: .footnote, color: .secondary)
                            }
                            .padding(.horizontal, Theme.margin)
                            .padding(.vertical, 10)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                }
            }

            if let verdict = diff.verdict?.trimmingCharacters(in: .whitespacesAndNewlines), !verdict.isEmpty {
                ResultSection(title: "Verdict") {
                    ResultCard {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.body)
                                .foregroundStyle(Color.accentColor)
                            InlineText(text: verdict)
                        }
                    }
                }
            }
        }
    }

    /// Original on a red 10% fill, struck through; revised on green 10%.
    private func block(symbol: String, text: String, tint: Color, strike: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 16)
            Text(text.isEmpty ? "Empty" : text)
                .font(.body)
                .strikethrough(strike)
                .foregroundStyle(strike ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.margin)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(strike ? "Original" : "Revised"): \(text)")
    }
}

// MARK: - Table

/// Stacked comparison cards: the first cell is the row's headline, the rest are label over value.
struct TableArtifactView: View {
    let table: TableArtifact
    var showsTitle: Bool = true

    private static let maxRows = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsTitle, !table.title.isEmpty {
                Text(table.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            if table.rows.isEmpty {
                EmptyArtifactCard(text: "No rows to compare.")
            }
            VStack(spacing: 12) {
                ForEach(Array(table.rows.prefix(Self.maxRows).enumerated()), id: \.offset) { _, row in
                    ResultCard {
                        VStack(alignment: .leading, spacing: 10) {
                            if let first = row.first, !first.isEmpty {
                                Text(first)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            ForEach(Array(row.dropFirst().enumerated()), id: \.offset) { index, value in
                                let column = table.columns[safe: index + 1] ?? ""
                                VStack(alignment: .leading, spacing: 2) {
                                    if !column.isEmpty {
                                        Text(column)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Text(value.isEmpty ? "–" : value)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if let note = table.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Grade report

struct GradeArtifactView: View {
    let report: GradeReport
    @State private var ringShown = false

    private var fraction: Double? { Self.fraction(from: report.score, items: report.items) }
    private var correctCount: Int { report.items.filter(\.correct).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ResultCard {
                HStack(spacing: 16) {
                    ring
                    VStack(alignment: .leading, spacing: 4) {
                        Text(headline)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }

            if !report.items.isEmpty {
                ResultSection(title: "Answers") {
                    ResultCard(padding: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(report.items.indices, id: \.self) { index in
                                let item = report.items[index]
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Image(systemName: item.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.body)
                                        .foregroundStyle(item.correct ? ResultPalette.good : ResultPalette.bad)
                                        .frame(width: 22)
                                        .accessibilityLabel(item.correct ? "Correct" : "Incorrect")
                                    VStack(alignment: .leading, spacing: 2) {
                                        InlineText(text: item.question.isEmpty ? "Question \(index + 1)" : item.question)
                                        if !item.yourAnswer.isEmpty {
                                            Text("Your answer: \(item.yourAnswer)")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        if let feedback = item.feedback, !feedback.isEmpty {
                                            InlineText(text: feedback, font: .footnote, color: .secondary)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, Theme.margin)
                                .padding(.vertical, 12)
                                .frame(minHeight: 44)
                                if index < report.items.count - 1 {
                                    Hairline().padding(.leading, Theme.margin + 22 + 12)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                    }
                }
            }

            if !report.weaknesses.isEmpty {
                ResultSection(title: "Weak spots") {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(report.weaknesses.enumerated()), id: \.offset) { _, weakness in
                            Text(weakness)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            if !report.nextSteps.isEmpty {
                ResultSection(title: "Next steps") {
                    ChecklistArtifactView(
                        checklist: Checklist(title: "Next steps", items: report.nextSteps.map { Checklist.Item(text: $0) }),
                        showsHeader: false
                    )
                }
            }
        }
        .onAppear { ringShown = true }
    }

    // MARK: Ring

    /// 88pt accent ring on a system-fill track; the score sits inside.
    private var ring: some View {
        let value = fraction ?? 0
        return ZStack {
            Circle()
                .stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 8)
            Circle()
                .trim(from: 0, to: ringShown ? CGFloat(value) : 0)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.smooth.delay(0.15), value: ringShown)
            VStack(spacing: 0) {
                Text(scoreLabel)
                    .font((scoreLabel.count > 4 ? Font.subheadline : Font.title3).weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let f = fraction, !scoreLabel.contains("%") {
                    Text("\(Int((f * 100).rounded()))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
        .frame(width: 88, height: 88)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(scoreLabel)")
    }

    private var scoreLabel: String {
        let trimmed = report.score.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if !report.items.isEmpty { return "\(correctCount)/\(report.items.count)" }
        return "—"
    }

    private var headline: String {
        guard let f = fraction else { return "Graded" }
        switch f {
        case 0.9...: return "Excellent work"
        case 0.75..<0.9: return "Solid result"
        case 0.5..<0.75: return "Getting there"
        default: return "Needs another pass"
        }
    }

    private var subline: String {
        if !report.items.isEmpty {
            return "\(correctCount) of \(report.items.count) correct"
        }
        return report.weaknesses.isEmpty ? "Review the notes below." : "\(report.weaknesses.count) areas to work on"
    }

    // MARK: Parsing

    /// Reads "7/10", "70%", "8 out of 10", "A-", or a bare number. Falls back to the item tally.
    static func fraction(from score: String, items: [GradeReport.Item]) -> Double? {
        let s = score.trimmingCharacters(in: .whitespacesAndNewlines)
        func numbers(_ text: Substring) -> [Double] {
            text.split(whereSeparator: { !($0.isNumber || $0 == ".") }).compactMap { Double($0) }
        }
        func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }

        if let r = s.range(of: #"\d+(\.\d+)?\s*/\s*\d+(\.\d+)?"#, options: .regularExpression) {
            let n = numbers(s[r])
            if n.count >= 2, n[1] > 0 { return clamp(n[0] / n[1]) }
        }
        if let r = s.range(of: #"\d+(\.\d+)?\s*(out\s+of|of)\s+\d+(\.\d+)?"#, options: [.regularExpression, .caseInsensitive]) {
            let n = numbers(s[r])
            if n.count >= 2, n[1] > 0 { return clamp(n[0] / n[1]) }
        }
        if let r = s.range(of: #"\d+(\.\d+)?\s*%"#, options: .regularExpression) {
            let n = numbers(s[r])
            if let v = n.first { return clamp(v / 100) }
        }
        if let r = s.range(of: #"\d+(\.\d+)?"#, options: .regularExpression), s.count <= 6 {
            if let v = numbers(s[r]).first {
                if v <= 1 { return clamp(v) }
                if v <= 10 { return clamp(v / 10) }
                if v <= 100 { return clamp(v / 100) }
            }
        }
        if s.count <= 2, let letter = s.uppercased().first {
            switch letter {
            case "A": return s.contains("+") ? 0.98 : (s.contains("-") ? 0.9 : 0.95)
            case "B": return s.contains("+") ? 0.88 : (s.contains("-") ? 0.8 : 0.85)
            case "C": return s.contains("+") ? 0.78 : (s.contains("-") ? 0.7 : 0.75)
            case "D": return 0.65
            case "E", "F": return 0.45
            default: break
            }
        }
        if !items.isEmpty {
            return clamp(Double(items.filter(\.correct).count) / Double(items.count))
        }
        return nil
    }
}

// MARK: - Image

struct ImageArtifactView: View {
    let image: ImageArtifact
    @Environment(\.fuseCompact) private var compact
    @State private var saveState: SaveState = .idle
    @State private var pulse = false
    @State private var saver = PhotoSaver()

    private let decoded: UIImage?

    init(image: ImageArtifact) {
        self.image = image
        self.decoded = image.uiImage
    }

    enum SaveState: Equatable {
        case idle, saving, saved
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let ui = decoded {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: compact ? 360 : 420)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    .accessibilityLabel(image.caption ?? "Generated image")

                if let caption = image.caption?.trimmingCharacters(in: .whitespacesAndNewlines), !caption.isEmpty {
                    InlineText(text: caption, font: .footnote, color: .secondary)
                        .padding(.horizontal, 4)
                }

                HStack(spacing: 8) {
                    switch saveState {
                    case .idle:
                        Button {
                            save(ui)
                        } label: {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                    case .saving:
                        WorkingLabel(title: "Saving…")
                    case .saved:
                        StatusPill(title: "Saved to Photos", symbol: "checkmark")
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    case .failed:
                        Button {
                            save(ui)
                        } label: {
                            Label("Try again", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                    }
                }
                .animation(Theme.snappy, value: saveState)

                if case .failed(let message) = saveState {
                    ErrorFootnote(message: message)
                }
            } else {
                ResultCard {
                    VStack(alignment: .leading, spacing: 12) {
                        // Generating placeholder: a system fill that breathes gently.
                        RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .frame(height: compact ? 160 : 200)
                            .overlay {
                                VStack(spacing: 8) {
                                    ProgressView()
                                    Text("Generating image…")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .opacity(pulse ? 1 : 0.6)
                            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                            .onAppear { pulse = true }
                            .accessibilityLabel("Generating image")

                        if !image.prompt.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Eyebrow(text: "Prompt")
                                Text(image.prompt)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if let caption = image.caption?.trimmingCharacters(in: .whitespacesAndNewlines), !caption.isEmpty {
                            Text(caption)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func save(_ ui: UIImage) {
        Haptics.tap()
        saveState = .saving
        saver.save(ui) { error in
            if let error {
                Haptics.warning()
                saveState = .failed(error.localizedDescription)
            } else {
                Haptics.success()
                saveState = .saved
            }
        }
    }
}

/// Objective-C bridge for `UIImageWriteToSavedPhotosAlbum`'s completion selector.
final class PhotoSaver: NSObject {
    private var completion: ((Error?) -> Void)?

    func save(_ image: UIImage, completion: @escaping (Error?) -> Void) {
        self.completion = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSaving(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func didFinishSaving(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer?) {
        let done = completion
        completion = nil
        DispatchQueue.main.async { done?(error) }
    }
}
