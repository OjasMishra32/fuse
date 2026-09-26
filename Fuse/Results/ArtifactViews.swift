import SwiftUI
import UIKit

// MARK: - Email

struct EmailArtifactView: View {
    let email: EmailDraft
    @State private var mailUnavailable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ResultCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    fieldRow("To", email.to.isEmpty ? "—" : email.to.joined(separator: ", "))
                    Hairline()
                    fieldRow("Subject", email.subject.isEmpty ? "(no subject)" : email.subject)
                    Hairline()
                    Text(email.body.isEmpty ? "(empty message)" : email.body)
                        .font(.fuseBody)
                        .foregroundStyle(email.body.isEmpty ? Theme.textTertiary : Theme.textPrimary.opacity(0.92))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            }

            FlowLayout(spacing: 10) {
                EnergyButton(title: "Open in Mail", symbol: "envelope") { openMail() }
                GlassCopyButton(text: plainBody)
            }

            if mailUnavailable {
                Text("Mail isn't set up on this device. The draft was copied instead.")
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
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
                .font(.fuseCaption)
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.fuseBody)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
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

/// Glass-styled copy button with a transient "Copied" state.
struct GlassCopyButton: View {
    var text: String
    @State private var copied = false

    var body: some View {
        GlassButton(title: copied ? "Copied" : "Copy", symbol: copied ? "checkmark" : "doc.on.doc") {
            UIPasteboard.general.string = text
            Haptics.soft()
            withAnimation(Theme.snappy) { copied = true }
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(Theme.snappy) { copied = false }
            }
        }
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
        let gutterWidth = CGFloat(String(max(shown.count, 1)).count) * 8 + 6

        VStack(alignment: .leading, spacing: 12) {
            ResultCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                        Text(code.filename?.isEmpty == false ? code.filename! : code.language)
                            .font(.fuseMono)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 8)
                        if code.filename?.isEmpty == false {
                            Text(code.language.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        CopyMiniButton(text: code.code)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Theme.ink3)
                    Hairline()

                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(shown.indices, id: \.self) { i in
                                HStack(alignment: .top, spacing: 14) {
                                    Text("\(i + 1)")
                                        .font(.fuseMono)
                                        .foregroundStyle(Theme.textTertiary)
                                        .frame(width: gutterWidth, alignment: .trailing)
                                    Text(shown[i].isEmpty ? " " : shown[i])
                                        .font(.fuseMono)
                                        .foregroundStyle(Theme.textPrimary.opacity(0.92))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .padding(.vertical, 1.5)
                            }
                        }
                        .padding(14)
                    }

                    if hidden > 0 {
                        Hairline()
                        Text("… \(hidden) more \(hidden == 1 ? "line" : "lines"). Copy to get everything.")
                            .font(.fuseCaption)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            }

            if let explanation = code.explanation?.trimmingCharacters(in: .whitespacesAndNewlines), !explanation.isEmpty {
                InlineText(text: explanation, color: Theme.textSecondary)
            }
        }
    }
}

// MARK: - Diff / redline

struct DiffArtifactView: View {
    let diff: RedlineDiff

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(diff.title)
                    .font(.fuseHeadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text(diff.changes.count == 1 ? "1 change" : "\(diff.changes.count) changes")
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textTertiary)
            }

            if diff.changes.isEmpty {
                ResultCard {
                    Text("No changes suggested.")
                        .font(.fuseBody)
                        .foregroundStyle(Theme.textSecondary)
                }
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
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.textTertiary)
                                InlineText(text: reason, font: .fuseCaption, color: Theme.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                }
            }

            if let verdict = diff.verdict?.trimmingCharacters(in: .whitespacesAndNewlines), !verdict.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Verdict")
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.violet)
                        InlineText(text: verdict, color: Theme.textPrimary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).stroke(Theme.violet.opacity(0.3), lineWidth: 1))
                }
                .padding(.top, 4)
            }
        }
    }

    private func block(symbol: String, text: String, tint: Color, strike: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 14)
            Text(text.isEmpty ? "(empty)" : text)
                .font(.fuseBody)
                .strikethrough(strike, color: tint.opacity(0.7))
                .foregroundStyle(strike ? Theme.textSecondary : Theme.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10))
    }
}

// MARK: - Table

struct TableArtifactView: View {
    let table: TableArtifact
    var showsTitle: Bool = true
    @Environment(\.fuseCompact) private var compact

    private static let maxRows = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTitle, !table.title.isEmpty {
                Text(table.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            // Stacked cards read well on a phone: the first column is the row's title, the
            // remaining columns become label + value lines. This never overflows.
            VStack(spacing: 10) {
                ForEach(Array(table.rows.prefix(Self.maxRows).enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 8) {
                        if let first = row.first, !first.isEmpty {
                            Text(first)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(Array(row.dropFirst().enumerated()), id: \.offset) { index, value in
                            let column = table.columns.indices.contains(index + 1) ? table.columns[index + 1] : ""
                            VStack(alignment: .leading, spacing: 2) {
                                if !column.isEmpty {
                                    Text(column)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(value.isEmpty ? "–" : value)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.groupedCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            if let note = table.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
}

struct GradeArtifactView: View {
    let report: GradeReport
    @Environment(\.fuseCompact) private var compact
    @State private var ringShown = false

    private var fraction: Double? { Self.fraction(from: report.score, items: report.items) }
    private var correctCount: Int { report.items.filter(\.correct).count }

    private var ringTint: Color {
        guard let f = fraction else { return Theme.violet }
        if f >= 0.7 { return ResultPalette.good }
        if f >= 0.5 { return ResultPalette.warn }
        return ResultPalette.bad
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ResultCard {
                HStack(spacing: compact ? 16 : 22) {
                    ring
                    VStack(alignment: .leading, spacing: 6) {
                        Text(headline)
                            .font(.fuseHeadline)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subline)
                            .font(.fuseBody)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }

            if !report.items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Answers")
                    ResultCard(padding: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(report.items.indices, id: \.self) { index in
                                let item = report.items[index]
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Image(systemName: item.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(item.correct ? ResultPalette.good : ResultPalette.bad)
                                    VStack(alignment: .leading, spacing: 3) {
                                        InlineText(text: item.question.isEmpty ? "Question \(index + 1)" : item.question)
                                        if !item.yourAnswer.isEmpty {
                                            Text("Your answer: \(item.yourAnswer)")
                                                .font(.fuseCaption)
                                                .foregroundStyle(Theme.textSecondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        if let feedback = item.feedback, !feedback.isEmpty {
                                            InlineText(text: feedback, font: .fuseCaption, color: Theme.textTertiary)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                if index < report.items.count - 1 {
                                    Hairline().padding(.leading, 43)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                    }
                }
            }

            if !report.weaknesses.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Weak spots")
                    FlowLayout(spacing: 8) {
                        ForEach(Array(report.weaknesses.enumerated()), id: \.offset) { _, weakness in
                            Text(weakness)
                                .font(.fuseCaption)
                                .foregroundStyle(ResultPalette.bad)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(ResultPalette.bad.opacity(0.12)))
                                .overlay(Capsule().stroke(ResultPalette.bad.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
            }

            if !report.nextSteps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Next steps")
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

    private var ring: some View {
        let size: CGFloat = compact ? 96 : 110
        let value = fraction ?? 0
        return ZStack {
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 9)
            Circle()
                .trim(from: 0, to: ringShown ? CGFloat(value) : 0)
                .stroke(ringTint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.smooth.delay(0.15), value: ringShown)
            VStack(spacing: 1) {
                Text(scoreLabel)
                    .font(.system(size: scoreLabel.count > 4 ? 17 : 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let f = fraction, !scoreLabel.contains("%") {
                    Text("\(Int((f * 100).rounded()))%")
                        .font(.fuseCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(14)
        }
        .frame(width: size, height: size)
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
                    .shadow(color: .black.opacity(0.35), radius: 20, y: 10)

                if let caption = image.caption?.trimmingCharacters(in: .whitespacesAndNewlines), !caption.isEmpty {
                    InlineText(text: caption, color: Theme.textSecondary)
                }

                HStack(spacing: 10) {
                    switch saveState {
                    case .idle:
                        EnergyButton(title: "Save to Photos", symbol: "square.and.arrow.down") { save(ui) }
                    case .saving:
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small).tint(Theme.textSecondary)
                            Text("Saving…").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                    case .saved:
                        StatusPill(title: "Saved to Photos", symbol: "checkmark", tint: ResultPalette.good)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    case .failed:
                        EnergyButton(title: "Try again", symbol: "arrow.clockwise") { save(ui) }
                    }
                }
                .animation(Theme.snappy, value: saveState)

                if case .failed(let message) = saveState {
                    Text(message)
                        .font(.fuseCaption)
                        .foregroundStyle(ResultPalette.bad)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ResultCard {
                    VStack(alignment: .leading, spacing: 14) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [Theme.ink3, Theme.ink2, Theme.ink3],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: compact ? 160 : 200)
                            .overlay {
                                VStack(spacing: 10) {
                                    ProgressView().tint(Theme.textSecondary)
                                    Text("Generating image…")
                                        .font(.fuseCaption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .opacity(pulse ? 1 : 0.55)
                            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                            .onAppear { pulse = true }

                        if !image.prompt.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow(text: "Prompt")
                                Text(image.prompt)
                                    .font(.fuseBody)
                                    .foregroundStyle(Theme.textPrimary.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if let caption = image.caption?.trimmingCharacters(in: .whitespacesAndNewlines), !caption.isEmpty {
                            Text(caption)
                                .font(.fuseCaption)
                                .foregroundStyle(Theme.textSecondary)
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
