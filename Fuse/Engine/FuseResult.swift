import Foundation
import UIKit

// MARK: - Result models
//
// The model answers with one JSON object:
//
// {
//   "recipe": "travel_plan",              // machine name of what it decided to do
//   "title": "Universal in one day",       // ≤ 6 words
//   "summary": "…",                        // 1–2 sentences, spoken-word friendly
//   "artifact": { "type": "itinerary", … },// one of the FuseArtifact cases below
//   "follow_ups": ["…", "…"]               // optional next fuses / actions
// }
//
// Decoding is lenient: unknown artifact types fall back to markdown so a creative model
// never produces a blank screen.

struct FuseResult: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var recipe: String
    var title: String
    var summary: String
    var artifact: FuseArtifact
    var followUps: [String] = []
    var inputs: [InputSummary] = []
    var instruction: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, createdAt, recipe, title, summary, artifact
        case followUps = "follow_ups"
        case inputs, instruction
    }

    init(recipe: String, title: String, summary: String, artifact: FuseArtifact, followUps: [String] = [], inputs: [InputSummary] = [], instruction: String? = nil) {
        self.recipe = recipe
        self.title = title
        self.summary = summary
        self.artifact = artifact
        self.followUps = followUps
        self.inputs = inputs
        self.instruction = instruction
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        recipe = try c.decodeIfPresent(String.self, forKey: .recipe) ?? "fuse"
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Fused"
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        artifact = try c.decodeIfPresent(FuseArtifact.self, forKey: .artifact) ?? .markdown(summary)
        followUps = try c.decodeIfPresent([String].self, forKey: .followUps) ?? []
        inputs = try c.decodeIfPresent([InputSummary].self, forKey: .inputs) ?? []
        instruction = try c.decodeIfPresent(String.self, forKey: .instruction)
    }
}

/// What went into the fuse, kept for history and the result header.
struct InputSummary: Codable, Hashable {
    var kind: SurfaceKind
    var title: String
}

// MARK: - Artifacts

enum FuseArtifact: Codable, Hashable {
    case markdown(String)
    case itinerary(Itinerary)
    case event(CalendarEventArtifact)
    case email(EmailDraft)
    case quiz(Quiz)
    case slides(SlideDeck)
    case code(CodeArtifact)
    case diff(RedlineDiff)
    case checklist(Checklist)
    case table(TableArtifact)
    case grade(GradeReport)
    case image(ImageArtifact)
    case openLate(OpenLatePlan)

    /// Wire name used in JSON (`"type"`).
    var typeName: String {
        switch self {
        case .markdown: "markdown"
        case .itinerary: "itinerary"
        case .event: "event"
        case .email: "email"
        case .quiz: "quiz"
        case .slides: "slides"
        case .code: "code"
        case .diff: "diff"
        case .checklist: "checklist"
        case .table: "table"
        case .grade: "grade"
        case .image: "image"
        case .openLate: "open_late"
        }
    }

    var symbol: String {
        switch self {
        case .markdown: "text.alignleft"
        case .itinerary: "map"
        case .event: "calendar.badge.plus"
        case .email: "envelope"
        case .quiz: "questionmark.circle"
        case .slides: "rectangle.on.rectangle"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .diff: "text.badge.checkmark"
        case .checklist: "checklist"
        case .table: "tablecells"
        case .grade: "graduationcap"
        case .image: "photo.on.rectangle.angled"
        case .openLate: "moon.stars"
        }
    }

    private enum CodingKeys: String, CodingKey { case type }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try c.decodeIfPresent(String.self, forKey: .type) ?? "markdown").lowercased()
        let single = try decoder.singleValueContainer()
        switch type {
        case "itinerary", "travel", "trip":
            self = .itinerary(try single.decode(Itinerary.self))
        case "event", "calendar", "calendar_event":
            self = .event(try single.decode(CalendarEventArtifact.self))
        case "email", "message", "draft":
            self = .email(try single.decode(EmailDraft.self))
        case "quiz", "test", "exam":
            self = .quiz(try single.decode(Quiz.self))
        case "slides", "presentation", "deck":
            self = .slides(try single.decode(SlideDeck.self))
        case "code", "patch":
            self = .code(try single.decode(CodeArtifact.self))
        case "diff", "redline", "review":
            self = .diff(try single.decode(RedlineDiff.self))
        case "checklist", "todo", "tasks":
            self = .checklist(try single.decode(Checklist.self))
        case "table", "comparison":
            self = .table(try single.decode(TableArtifact.self))
        case "grade", "grading", "score":
            self = .grade(try single.decode(GradeReport.self))
        case "image", "image_edit", "photo":
            self = .image(try single.decode(ImageArtifact.self))
        case "open_late", "open_now", "still_open", "late_night":
            self = .openLate(try single.decode(OpenLatePlan.self))
        default:
            let md = try single.decode(MarkdownBox.self)
            self = .markdown(md.markdown)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(typeName, forKey: .type)
        var single = encoder.singleValueContainer()
        switch self {
        case .markdown(let s): try MarkdownBox(markdown: s).encode(to: encoder)
        case .itinerary(let v): try single.encode(v)
        case .event(let v): try single.encode(v)
        case .email(let v): try single.encode(v)
        case .quiz(let v): try single.encode(v)
        case .slides(let v): try single.encode(v)
        case .code(let v): try single.encode(v)
        case .diff(let v): try single.encode(v)
        case .checklist(let v): try single.encode(v)
        case .table(let v): try single.encode(v)
        case .grade(let v): try single.encode(v)
        case .image(let v): try single.encode(v)
        case .openLate(let v): try single.encode(v)
        }
    }

    private struct MarkdownBox: Codable {
        var markdown: String
        init(markdown: String) { self.markdown = markdown }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            markdown = try c.decodeIfPresent(String.self, forKey: .markdown)
                ?? c.decodeIfPresent(String.self, forKey: .text)
                ?? c.decodeIfPresent(String.self, forKey: .content)
                ?? c.decodeIfPresent(String.self, forKey: .body)
                ?? ""
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(markdown, forKey: .markdown)
        }
        enum Keys: String, CodingKey { case markdown, text, content, body }
    }
}

// MARK: Itinerary

struct Itinerary: Codable, Hashable {
    struct Stop: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var name: String
        var time: String?
        var note: String?
        var latitude: Double?
        var longitude: Double?

        enum CodingKeys: String, CodingKey { case name, time, note, latitude, longitude, lat, lon, lng }
        init(name: String, time: String? = nil, note: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
            self.name = name; self.time = time; self.note = note; self.latitude = latitude; self.longitude = longitude
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Stop"
            time = try c.decodeIfPresent(String.self, forKey: .time)
            note = try c.decodeIfPresent(String.self, forKey: .note)
            latitude = try c.decodeIfPresent(Double.self, forKey: .latitude) ?? c.decodeIfPresent(Double.self, forKey: .lat)
            longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
                ?? c.decodeIfPresent(Double.self, forKey: .lon)
                ?? c.decodeIfPresent(Double.self, forKey: .lng)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encodeIfPresent(time, forKey: .time)
            try c.encodeIfPresent(note, forKey: .note)
            try c.encodeIfPresent(latitude, forKey: .latitude)
            try c.encodeIfPresent(longitude, forKey: .longitude)
        }
    }
    struct Day: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var title: String
        var stops: [Stop]
        enum CodingKeys: String, CodingKey { case title, stops }
        init(title: String, stops: [Stop]) { self.title = title; self.stops = stops }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Day"
            stops = try c.decodeIfPresent([Stop].self, forKey: .stops) ?? []
        }
    }
    var destination: String
    var days: [Day]
    var tips: [String]

    enum CodingKeys: String, CodingKey { case destination, days, tips }
    init(destination: String, days: [Day], tips: [String] = []) { self.destination = destination; self.days = days; self.tips = tips }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        destination = try c.decodeIfPresent(String.self, forKey: .destination) ?? "Trip"
        days = try c.decodeIfPresent([Day].self, forKey: .days) ?? []
        tips = try c.decodeIfPresent([String].self, forKey: .tips) ?? []
    }

    var allStops: [Stop] { days.flatMap(\.stops) }
}

// MARK: Calendar event

struct CalendarEventArtifact: Codable, Hashable {
    var title: String
    /// ISO-8601 (`2026-10-03T18:00:00`), optionally with zone. Parsed leniently by `startDate`.
    var start: String
    var end: String?
    var location: String?
    var notes: String?
    var allDay: Bool
    var attendees: [String]

    enum CodingKeys: String, CodingKey { case title, start, end, location, notes, attendees
        case allDay = "all_day" }

    init(title: String, start: String, end: String? = nil, location: String? = nil, notes: String? = nil, allDay: Bool = false, attendees: [String] = []) {
        self.title = title; self.start = start; self.end = end; self.location = location; self.notes = notes; self.allDay = allDay; self.attendees = attendees
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Event"
        start = try c.decodeIfPresent(String.self, forKey: .start) ?? ""
        end = try c.decodeIfPresent(String.self, forKey: .end)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        allDay = try c.decodeIfPresent(Bool.self, forKey: .allDay) ?? false
        attendees = try c.decodeIfPresent([String].self, forKey: .attendees) ?? []
    }

    var startDate: Date? { FuseDates.parse(start) }
    var endDate: Date? { end.flatMap(FuseDates.parse) ?? startDate.map { $0.addingTimeInterval(3600) } }
}

enum FuseDates {
    static func parse(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: trimmed) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: trimmed) { return d }
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            local.dateFormat = fmt
            if let d = local.date(from: trimmed) { return d }
        }
        return nil
    }
}

// MARK: Email

struct EmailDraft: Codable, Hashable {
    var to: [String]
    var subject: String
    var body: String
    enum CodingKeys: String, CodingKey { case to, subject, body }
    init(to: [String], subject: String, body: String) { self.to = to; self.subject = subject; self.body = body }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let list = try? c.decodeIfPresent([String].self, forKey: .to) { to = list }
        else if let one = try? c.decodeIfPresent(String.self, forKey: .to) { to = [one] }
        else { to = [] }
        subject = try c.decodeIfPresent(String.self, forKey: .subject) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
    }
}

// MARK: Quiz

struct Quiz: Codable, Hashable {
    struct Question: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var prompt: String
        var choices: [String]
        var answerIndex: Int
        var explanation: String?
        enum CodingKeys: String, CodingKey { case prompt, question, choices, options, explanation
            case answerIndex = "answer_index" }
        init(prompt: String, choices: [String], answerIndex: Int, explanation: String? = nil) {
            self.prompt = prompt; self.choices = choices; self.answerIndex = answerIndex; self.explanation = explanation
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            prompt = try c.decodeIfPresent(String.self, forKey: .prompt) ?? c.decodeIfPresent(String.self, forKey: .question) ?? ""
            choices = try c.decodeIfPresent([String].self, forKey: .choices) ?? c.decodeIfPresent([String].self, forKey: .options) ?? []
            answerIndex = try c.decodeIfPresent(Int.self, forKey: .answerIndex) ?? 0
            explanation = try c.decodeIfPresent(String.self, forKey: .explanation)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(prompt, forKey: .prompt); try c.encode(choices, forKey: .choices)
            try c.encode(answerIndex, forKey: .answerIndex); try c.encodeIfPresent(explanation, forKey: .explanation)
        }
    }
    var title: String
    var questions: [Question]
    enum CodingKeys: String, CodingKey { case title, questions }
    init(title: String, questions: [Question]) { self.title = title; self.questions = questions }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Quiz"
        questions = try c.decodeIfPresent([Question].self, forKey: .questions) ?? []
    }
}

// MARK: Slides

struct SlideDeck: Codable, Hashable {
    struct Slide: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var title: String
        var bullets: [String]
        var notes: String?
        enum CodingKeys: String, CodingKey { case title, bullets, notes, points }
        init(title: String, bullets: [String], notes: String? = nil) { self.title = title; self.bullets = bullets; self.notes = notes }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            bullets = try c.decodeIfPresent([String].self, forKey: .bullets) ?? c.decodeIfPresent([String].self, forKey: .points) ?? []
            notes = try c.decodeIfPresent(String.self, forKey: .notes)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(title, forKey: .title); try c.encode(bullets, forKey: .bullets); try c.encodeIfPresent(notes, forKey: .notes)
        }
    }
    var title: String
    var slides: [Slide]
    enum CodingKeys: String, CodingKey { case title, slides }
    init(title: String, slides: [Slide]) { self.title = title; self.slides = slides }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Deck"
        slides = try c.decodeIfPresent([Slide].self, forKey: .slides) ?? []
    }
}

// MARK: Code

struct CodeArtifact: Codable, Hashable {
    var language: String
    var filename: String?
    var code: String
    var explanation: String?
    enum CodingKeys: String, CodingKey { case language, filename, code, explanation }
    init(language: String, filename: String? = nil, code: String, explanation: String? = nil) {
        self.language = language; self.filename = filename; self.code = code; self.explanation = explanation
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? "text"
        filename = try c.decodeIfPresent(String.self, forKey: .filename)
        code = try c.decodeIfPresent(String.self, forKey: .code) ?? ""
        explanation = try c.decodeIfPresent(String.self, forKey: .explanation)
    }
}

// MARK: Diff / redline

struct RedlineDiff: Codable, Hashable {
    struct Change: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var original: String
        var revised: String
        var reason: String?
        enum CodingKeys: String, CodingKey { case original, revised, reason, before, after }
        init(original: String, revised: String, reason: String? = nil) { self.original = original; self.revised = revised; self.reason = reason }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            original = try c.decodeIfPresent(String.self, forKey: .original) ?? c.decodeIfPresent(String.self, forKey: .before) ?? ""
            revised = try c.decodeIfPresent(String.self, forKey: .revised) ?? c.decodeIfPresent(String.self, forKey: .after) ?? ""
            reason = try c.decodeIfPresent(String.self, forKey: .reason)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(original, forKey: .original); try c.encode(revised, forKey: .revised); try c.encodeIfPresent(reason, forKey: .reason)
        }
    }
    var title: String
    var changes: [Change]
    var verdict: String?
    enum CodingKeys: String, CodingKey { case title, changes, verdict }
    init(title: String, changes: [Change], verdict: String? = nil) { self.title = title; self.changes = changes; self.verdict = verdict }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Redline"
        changes = try c.decodeIfPresent([Change].self, forKey: .changes) ?? []
        verdict = try c.decodeIfPresent(String.self, forKey: .verdict)
    }
}

// MARK: Checklist

struct Checklist: Codable, Hashable {
    struct Item: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var text: String
        var detail: String?
        enum CodingKeys: String, CodingKey { case text, detail, title }
        init(text: String, detail: String? = nil) { self.text = text; self.detail = detail }
        init(from decoder: Decoder) throws {
            if let single = try? decoder.singleValueContainer(), let s = try? single.decode(String.self) {
                text = s; detail = nil; return
            }
            let c = try decoder.container(keyedBy: CodingKeys.self)
            text = try c.decodeIfPresent(String.self, forKey: .text) ?? c.decodeIfPresent(String.self, forKey: .title) ?? ""
            detail = try c.decodeIfPresent(String.self, forKey: .detail)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(text, forKey: .text); try c.encodeIfPresent(detail, forKey: .detail)
        }
    }
    var title: String
    var items: [Item]
    enum CodingKeys: String, CodingKey { case title, items }
    init(title: String, items: [Item]) { self.title = title; self.items = items }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Checklist"
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
    }
}

// MARK: Table

struct TableArtifact: Codable, Hashable {
    var title: String
    var columns: [String]
    var rows: [[String]]
    var note: String?
    enum CodingKeys: String, CodingKey { case title, columns, rows, note }
    init(title: String, columns: [String], rows: [[String]], note: String? = nil) { self.title = title; self.columns = columns; self.rows = rows; self.note = note }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Comparison"
        columns = try c.decodeIfPresent([String].self, forKey: .columns) ?? []
        rows = try c.decodeIfPresent([[String]].self, forKey: .rows) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }
}

// MARK: Grade report (test checking)

struct GradeReport: Codable, Hashable {
    struct Item: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var question: String
        var yourAnswer: String
        var correct: Bool
        var feedback: String?
        enum CodingKeys: String, CodingKey { case question, correct, feedback
            case yourAnswer = "your_answer" }
        init(question: String, yourAnswer: String, correct: Bool, feedback: String? = nil) {
            self.question = question; self.yourAnswer = yourAnswer; self.correct = correct; self.feedback = feedback
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            question = try c.decodeIfPresent(String.self, forKey: .question) ?? ""
            yourAnswer = try c.decodeIfPresent(String.self, forKey: .yourAnswer) ?? ""
            correct = try c.decodeIfPresent(Bool.self, forKey: .correct) ?? false
            feedback = try c.decodeIfPresent(String.self, forKey: .feedback)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(question, forKey: .question); try c.encode(yourAnswer, forKey: .yourAnswer)
            try c.encode(correct, forKey: .correct); try c.encodeIfPresent(feedback, forKey: .feedback)
        }
    }
    var score: String
    var items: [Item]
    var weaknesses: [String]
    var nextSteps: [String]
    enum CodingKeys: String, CodingKey { case score, items, weaknesses
        case nextSteps = "next_steps" }
    init(score: String, items: [Item], weaknesses: [String] = [], nextSteps: [String] = []) {
        self.score = score; self.items = items; self.weaknesses = weaknesses; self.nextSteps = nextSteps
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        score = try c.decodeIfPresent(String.self, forKey: .score) ?? ""
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        weaknesses = try c.decodeIfPresent([String].self, forKey: .weaknesses) ?? []
        nextSteps = try c.decodeIfPresent([String].self, forKey: .nextSteps) ?? []
    }
}

// MARK: Still open (places you can reach before they close)

struct OpenLatePlan: Codable, Hashable {
    struct Spot: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var name: String
        var category: String?
        var address: String?
        /// Closing time as people say it: "12:30 AM".
        var closes: String
        /// Closing time as local ISO-8601, for a live countdown when it parses.
        var closesAt: String?
        /// "8 min walk", "6 min drive".
        var travel: String?
        var leaveBy: String?
        /// Minutes at the table (or in the shop) between arriving and closing.
        var minutesToSpare: Int?
        var note: String?
        var latitude: Double?
        var longitude: Double?

        enum CodingKeys: String, CodingKey {
            case name, category, address, closes, travel, note, latitude, longitude, lat, lon, lng
            case closesAt = "closes_at", leaveBy = "leave_by", minutesToSpare = "minutes_to_spare"
        }
        init(name: String, category: String? = nil, address: String? = nil, closes: String, closesAt: String? = nil,
             travel: String? = nil, leaveBy: String? = nil, minutesToSpare: Int? = nil, note: String? = nil,
             latitude: Double? = nil, longitude: Double? = nil) {
            self.name = name; self.category = category; self.address = address; self.closes = closes; self.closesAt = closesAt
            self.travel = travel; self.leaveBy = leaveBy; self.minutesToSpare = minutesToSpare; self.note = note
            self.latitude = latitude; self.longitude = longitude
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Place"
            category = try c.decodeIfPresent(String.self, forKey: .category)
            address = try c.decodeIfPresent(String.self, forKey: .address)
            closes = try c.decodeIfPresent(String.self, forKey: .closes) ?? ""
            closesAt = try c.decodeIfPresent(String.self, forKey: .closesAt)
            travel = try c.decodeIfPresent(String.self, forKey: .travel)
            leaveBy = try c.decodeIfPresent(String.self, forKey: .leaveBy)
            // Models sometimes write 45.0; a string or garbage just means "unknown".
            if let minutes = try? c.decodeIfPresent(Double.self, forKey: .minutesToSpare), minutes.isFinite {
                minutesToSpare = Int(minutes)
            } else {
                minutesToSpare = nil
            }
            note = try c.decodeIfPresent(String.self, forKey: .note)
            latitude = try c.decodeIfPresent(Double.self, forKey: .latitude) ?? c.decodeIfPresent(Double.self, forKey: .lat)
            longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
                ?? c.decodeIfPresent(Double.self, forKey: .lon)
                ?? c.decodeIfPresent(Double.self, forKey: .lng)
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encodeIfPresent(category, forKey: .category)
            try c.encodeIfPresent(address, forKey: .address)
            try c.encode(closes, forKey: .closes)
            try c.encodeIfPresent(closesAt, forKey: .closesAt)
            try c.encodeIfPresent(travel, forKey: .travel)
            try c.encodeIfPresent(leaveBy, forKey: .leaveBy)
            try c.encodeIfPresent(minutesToSpare, forKey: .minutesToSpare)
            try c.encodeIfPresent(note, forKey: .note)
            try c.encodeIfPresent(latitude, forKey: .latitude)
            try c.encodeIfPresent(longitude, forKey: .longitude)
        }

        var closesDate: Date? { closesAt.flatMap(FuseDates.parse) }

        /// "Closes 12:30 AM · 8 min walk · leave by 12:05 AM".
        var summaryLine: String {
            var parts: [String] = []
            if !closes.isEmpty { parts.append("Closes \(closes)") }
            if let travel, !travel.isEmpty { parts.append(travel) }
            if let leaveBy, !leaveBy.isEmpty { parts.append("leave by \(leaveBy)") }
            return parts.joined(separator: " · ")
        }
    }

    struct Missed: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var name: String
        var reason: String
        enum CodingKeys: String, CodingKey { case name, reason }
        init(name: String, reason: String) { self.name = name; self.reason = reason }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Place"
            reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
        }
    }

    /// Where the user is starting from: "Palmer House, 17 E Monroe St".
    var origin: String
    var originLatitude: Double?
    var originLongitude: Double?
    /// The time the plan was made for: "11:10 PM".
    var now: String?
    var spots: [Spot]
    var missed: [Missed]
    var tip: String?

    enum CodingKeys: String, CodingKey {
        case origin, now, spots, places, missed, tip
        case originLatitude = "origin_latitude", originLongitude = "origin_longitude"
    }
    init(origin: String, originLatitude: Double? = nil, originLongitude: Double? = nil, now: String? = nil,
         spots: [Spot], missed: [Missed] = [], tip: String? = nil) {
        self.origin = origin; self.originLatitude = originLatitude; self.originLongitude = originLongitude
        self.now = now; self.spots = spots; self.missed = missed; self.tip = tip
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        origin = try c.decodeIfPresent(String.self, forKey: .origin) ?? ""
        originLatitude = try? c.decodeIfPresent(Double.self, forKey: .originLatitude)
        originLongitude = try? c.decodeIfPresent(Double.self, forKey: .originLongitude)
        now = try c.decodeIfPresent(String.self, forKey: .now)
        spots = try c.decodeIfPresent([Spot].self, forKey: .spots) ?? c.decodeIfPresent([Spot].self, forKey: .places) ?? []
        missed = try c.decodeIfPresent([Missed].self, forKey: .missed) ?? []
        tip = try c.decodeIfPresent(String.self, forKey: .tip)
    }
    /// Plain text for copying, sharing and the Safari popup.
    var lines: [String] {
        var out: [String] = []
        let header = [origin.isEmpty ? nil : "From \(origin)", now.map { "at \($0)" }].compactMap { $0 }.joined(separator: " ")
        if !header.isEmpty { out.append(header) }
        for (i, spot) in spots.enumerated() {
            out.append("\(i + 1). \(spot.name)" + (spot.summaryLine.isEmpty ? "" : ": \(spot.summaryLine)"))
        }
        if !missed.isEmpty {
            out.append("")
            out.append("Too late tonight")
            out.append(contentsOf: missed.map { "• \($0.name)" + ($0.reason.isEmpty ? "" : ": \($0.reason)") })
        }
        if let tip, !tip.isEmpty { out.append(""); out.append(tip) }
        return out
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(origin, forKey: .origin)
        try c.encodeIfPresent(originLatitude, forKey: .originLatitude)
        try c.encodeIfPresent(originLongitude, forKey: .originLongitude)
        try c.encodeIfPresent(now, forKey: .now)
        try c.encode(spots, forKey: .spots)
        try c.encode(missed, forKey: .missed)
        try c.encodeIfPresent(tip, forKey: .tip)
    }
}

// MARK: Image (generated / edited)

struct ImageArtifact: Codable, Hashable {
    /// The edit/generation prompt the router wrote. The engine fills `imageBase64` after generation.
    var prompt: String
    var caption: String?
    var imageBase64: String?
    enum CodingKeys: String, CodingKey { case prompt, caption
        case imageBase64 = "image_base64" }
    init(prompt: String, caption: String? = nil, imageBase64: String? = nil) { self.prompt = prompt; self.caption = caption; self.imageBase64 = imageBase64 }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prompt = try c.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        caption = try c.decodeIfPresent(String.self, forKey: .caption)
        imageBase64 = try c.decodeIfPresent(String.self, forKey: .imageBase64)
    }
    var uiImage: UIImage? {
        guard let b64 = imageBase64, let data = Data(base64Encoded: b64) else { return nil }
        return UIImage(data: data)
    }
}
