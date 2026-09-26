import Foundation

// MARK: - Compact text for artifacts (used outside the app, e.g. the Safari popup)

extension FuseArtifact {
    var compactText: String {
        switch self {
        case .markdown(let md): return md
        case .itinerary(let it):
            return it.days.map { day in
                ([day.title] + day.stops.map { "• \($0.time.map { $0 + "  " } ?? "")\($0.name)\($0.note.map { ": " + $0 } ?? "")" }).joined(separator: "\n")
            }.joined(separator: "\n\n") + (it.tips.isEmpty ? "" : "\n\nTips\n" + it.tips.map { "• " + $0 }.joined(separator: "\n"))
        case .event(let e):
            return [e.title, e.start + (e.end.map { " to " + $0 } ?? ""), e.location ?? "", e.notes ?? ""].filter { !$0.isEmpty }.joined(separator: "\n")
        case .email(let m):
            return "To: \(m.to.joined(separator: ", "))\nSubject: \(m.subject)\n\n\(m.body)"
        case .quiz(let q):
            return q.questions.enumerated().map { i, qu in "\(i + 1). \(qu.prompt)\n" + qu.choices.enumerated().map { j, c in "   \(["A","B","C","D","E","F"][min(j, 5)]). \(c)" }.joined(separator: "\n") }.joined(separator: "\n\n")
        case .slides(let d):
            return d.slides.enumerated().map { i, s in "Slide \(i + 1): \(s.title)\n" + s.bullets.map { "• " + $0 }.joined(separator: "\n") }.joined(separator: "\n\n")
        case .code(let c):
            return (c.filename.map { $0 + "\n" } ?? "") + c.code + (c.explanation.map { "\n\n" + $0 } ?? "")
        case .diff(let d):
            return d.changes.map { "− \($0.original)\n+ \($0.revised)" + ($0.reason.map { "\n  \($0)" } ?? "") }.joined(separator: "\n\n") + (d.verdict.map { "\n\n" + $0 } ?? "")
        case .checklist(let c):
            return c.items.map { "☐ " + $0.text + ($0.detail.map { ": " + $0 } ?? "") }.joined(separator: "\n")
        case .table(let t):
            return ([t.columns.joined(separator: " | ")] + t.rows.map { $0.joined(separator: " | ") }).joined(separator: "\n") + (t.note.map { "\n\n" + $0 } ?? "")
        case .grade(let g):
            return "Score: \(g.score)\n" + g.items.map { ($0.correct ? "✓ " : "✗ ") + $0.question + ($0.feedback.map { ": " + $0 } ?? "") }.joined(separator: "\n") + (g.weaknesses.isEmpty ? "" : "\n\nWork on: " + g.weaknesses.joined(separator: ", "))
        case .image(let i):
            return i.caption ?? i.prompt
        }
    }
}
