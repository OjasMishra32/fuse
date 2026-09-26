import SwiftUI

// MARK: - Markdown
//
// A deliberately small block-level renderer: headings, lists (bulleted, numbered, tasks),
// quotes, fenced code, rules, pipe tables, paragraphs. Inline styling is handled by
// Foundation's markdown parser. Odd input degrades to plain paragraphs — it never throws.

struct MarkdownArtifactView: View {
    let markdown: String
    private let blocks: [MarkdownBlock]

    init(markdown: String) {
        self.markdown = markdown
        self.blocks = MarkdownParser.parse(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if blocks.isEmpty {
                InlineText(text: markdown.isEmpty ? "Nothing to show." : markdown, color: .secondary)
            } else {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    MarkdownBlockView(block: block)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Model

enum MarkdownBlock {
    struct ListItem {
        enum Marker {
            case bullet
            case number(Int)
            case task(done: Bool)
        }
        var level: Int
        var marker: Marker
        var text: String
    }

    case heading(level: Int, text: String)
    case paragraph(String)
    case list([ListItem])
    case quote(String)
    case code(language: String?, code: String)
    case rule
    case table(TableArtifact)
}

// MARK: Parser

enum MarkdownParser {
    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var listItems: [MarkdownBlock.ListItem] = []
        var quoteLines: [String] = []
        var tableLines: [String] = []
        var codeLines: [String]? = nil
        var codeLanguage: String? = nil

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph.removeAll()
            }
        }
        func flushList() {
            if !listItems.isEmpty {
                blocks.append(.list(listItems))
                listItems.removeAll()
            }
        }
        func flushQuote() {
            if !quoteLines.isEmpty {
                blocks.append(.quote(quoteLines.joined(separator: "\n")))
                quoteLines.removeAll()
            }
        }
        func flushTable() {
            if !tableLines.isEmpty {
                if let table = makeTable(tableLines) {
                    blocks.append(.table(table))
                } else {
                    blocks.append(.paragraph(tableLines.joined(separator: "\n")))
                }
                tableLines.removeAll()
            }
        }
        func flushAll() {
            flushParagraph(); flushList(); flushQuote(); flushTable()
        }

        let lines = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            // Inside a fenced code block: collect until the closing fence.
            if let existing = codeLines {
                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                    blocks.append(.code(language: codeLanguage, code: existing.joined(separator: "\n")))
                    codeLines = nil
                    codeLanguage = nil
                } else {
                    codeLines = existing + [raw.replacingOccurrences(of: "\t", with: "    ")]
                }
                continue
            }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flushAll()
                let lang = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                codeLanguage = lang.isEmpty ? nil : lang
                codeLines = []
                continue
            }

            if trimmed.isEmpty {
                flushAll()
                continue
            }

            // Headings
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix(while: { $0 == "#" }).count
                let rest = trimmed.dropFirst(hashes)
                if hashes <= 6, rest.isEmpty || rest.first == " " {
                    flushAll()
                    var text = rest.trimmingCharacters(in: .whitespaces)
                    while text.hasSuffix("#") { text.removeLast() }
                    blocks.append(.heading(level: hashes, text: text.trimmingCharacters(in: .whitespaces)))
                    continue
                }
            }

            // Horizontal rule
            if isRule(trimmed) {
                flushAll()
                blocks.append(.rule)
                continue
            }

            // Block quote
            if trimmed.hasPrefix(">") {
                flushParagraph(); flushList(); flushTable()
                var inner = trimmed.dropFirst()
                if inner.first == " " { inner = inner.dropFirst() }
                quoteLines.append(String(inner))
                continue
            }

            // Pipe table row
            if trimmed.hasPrefix("|"), trimmed.count > 1 {
                flushParagraph(); flushList(); flushQuote()
                tableLines.append(trimmed)
                continue
            }

            // List items
            let indentColumns = raw.prefix(while: { $0 == " " || $0 == "\t" })
                .reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
            let level = min(indentColumns / 2, 3)
            if let item = parseListItem(trimmed, level: level) {
                flushParagraph(); flushQuote(); flushTable()
                listItems.append(item)
                continue
            }

            // Lazy continuation of the previous list item.
            if !listItems.isEmpty, indentColumns > 0 {
                listItems[listItems.count - 1].text += " " + trimmed
                continue
            }

            flushList(); flushQuote(); flushTable()
            paragraph.append(trimmed)
        }

        if let unterminated = codeLines {
            blocks.append(.code(language: codeLanguage, code: unterminated.joined(separator: "\n")))
        }
        flushAll()
        return blocks
    }

    private static func isRule(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    private static func parseListItem(_ line: String, level: Int) -> MarkdownBlock.ListItem? {
        // Task items: "- [ ] text" / "- [x] text"
        for prefix in ["- [ ] ", "* [ ] ", "+ [ ] "] where line.hasPrefix(prefix) {
            return .init(level: level, marker: .task(done: false), text: String(line.dropFirst(prefix.count)))
        }
        for prefix in ["- [x] ", "- [X] ", "* [x] ", "* [X] ", "+ [x] ", "+ [X] "] where line.hasPrefix(prefix) {
            return .init(level: level, marker: .task(done: true), text: String(line.dropFirst(prefix.count)))
        }
        // Bullets
        if let first = line.first, "-*+•".contains(first) {
            let rest = line.dropFirst()
            if rest.first == " " || rest.first == "\t" {
                return .init(level: level, marker: .bullet, text: rest.trimmingCharacters(in: .whitespaces))
            }
        }
        // Numbered: "1. text" or "1) text"
        let digits = line.prefix(while: { $0.isNumber })
        if !digits.isEmpty, digits.count <= 3 {
            let afterDigits = line.dropFirst(digits.count)
            if let punct = afterDigits.first, punct == "." || punct == ")" {
                let rest = afterDigits.dropFirst()
                if rest.first == " " {
                    return .init(level: level, marker: .number(Int(digits) ?? 1), text: rest.trimmingCharacters(in: .whitespaces))
                }
            }
        }
        return nil
    }

    private static func makeTable(_ lines: [String]) -> TableArtifact? {
        func cells(_ line: String) -> [String] {
            var body = Substring(line)
            if body.hasPrefix("|") { body = body.dropFirst() }
            if body.hasSuffix("|") { body = body.dropLast() }
            return body.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        func isSeparator(_ row: [String]) -> Bool {
            !row.isEmpty && row.allSatisfy { cell in
                let c = cell.replacingOccurrences(of: ":", with: "")
                return !c.isEmpty && c.allSatisfy { $0 == "-" }
            }
        }
        let rows = lines.map(cells).filter { !isSeparator($0) }
        guard let header = rows.first, !header.isEmpty else { return nil }
        let body = rows.dropFirst().map { row -> [String] in
            var padded = row
            while padded.count < header.count { padded.append("") }
            return Array(padded.prefix(header.count))
        }
        return TableArtifact(title: "", columns: header, rows: Array(body))
    }
}

// MARK: Block rendering

struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case .heading(let level, let text):
            heading(level: level, text: text)
        case .paragraph(let text):
            InlineText(text: text)
        case .list(let items):
            list(items)
        case .quote(let text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(.tertiary)
                    .frame(width: 3)
                InlineText(text: text, color: .secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 2)
        case .code(let language, let code):
            codeBlock(language: language, code: code)
        case .rule:
            Hairline().padding(.vertical, 4)
        case .table(let table):
            TableArtifactView(table: table, showsTitle: false)
        }
    }

    /// # → title3, ## → headline, ### and deeper → subheadline. All SF text styles.
    @ViewBuilder
    private func heading(level: Int, text: String) -> some View {
        let font: Font = switch level {
        case 1: .title3.weight(.semibold)
        case 2: .headline
        default: .subheadline.weight(.semibold)
        }
        Text(InlineMarkdown.attributed(text))
            .font(font)
            .foregroundStyle(level >= 3 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, level <= 2 ? 8 : 4)
    }

    /// Hanging indent: a fixed-width marker column, text wraps under itself.
    private func list(_ items: [MarkdownBlock.ListItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    marker(item.marker)
                        .frame(minWidth: 24, alignment: .trailing)
                    InlineText(text: item.text)
                }
                .padding(.leading, CGFloat(item.level) * 20)
            }
        }
    }

    @ViewBuilder
    private func marker(_ marker: MarkdownBlock.ListItem.Marker) -> some View {
        switch marker {
        case .bullet:
            Text("•")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
        case .number(let n):
            Text("\(n).")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        case .task(let done):
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(done ? Color.accentColor : Color(uiColor: .tertiaryLabel))
                .accessibilityLabel(done ? "Done" : "To do")
        }
    }

    /// Monospaced card: optional language row with Copy, then the code scrolling sideways.
    private func codeBlock(language: String?, code: String) -> some View {
        ResultCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text((language?.isEmpty == false ? language! : "Code").uppercased())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    CopyButton(text: code, size: .small)
                }
                .padding(.horizontal, Theme.margin)
                .padding(.vertical, 8)
                Hairline()
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.fuseMono)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: true)
                        .padding(Theme.margin)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        }
    }
}
