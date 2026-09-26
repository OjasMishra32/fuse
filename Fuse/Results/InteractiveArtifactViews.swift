import SwiftUI

// MARK: - Quiz

struct QuizArtifactView: View {
    let quiz: Quiz
    @State private var answers: [Int: Int] = [:]
    @State private var revealAll = false

    private var total: Int { quiz.questions.count }
    private var answered: Int { answers.count }
    private var correct: Int {
        answers.reduce(0) { acc, pair in
            guard let q = quiz.questions[safe: pair.key] else { return acc }
            return acc + (q.answerIndex == pair.value ? 1 : 0)
        }
    }
    private var allCorrect: Bool { total > 0 && correct == total }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ResultCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(quiz.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        scorePill
                    }
                    ProgressView(value: total == 0 ? 0 : Double(answered) / Double(total))
                        .tint(allCorrect ? ResultPalette.good : Color.accentColor)
                        .animation(Theme.snappy, value: answered)
                    HStack(spacing: 8) {
                        Text(answered == total && total > 0 ? "All answered" : "\(answered) of \(total) answered")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                        Spacer(minLength: 8)
                        if answered > 0 || revealAll {
                            MiniButton(title: "Reset", symbol: "arrow.counterclockwise") {
                                Haptics.tap()
                                withAnimation(Theme.snappy) { answers.removeAll(); revealAll = false }
                            }
                        }
                        MiniButton(title: revealAll ? "Hide" : "Reveal", symbol: revealAll ? "eye.slash" : "eye") {
                            Haptics.tap()
                            withAnimation(Theme.snappy) { revealAll.toggle() }
                        }
                    }
                }
            }

            if quiz.questions.isEmpty {
                EmptyArtifactCard(text: "No questions were generated.")
            }

            ForEach(quiz.questions.indices, id: \.self) { index in
                QuestionCard(number: index + 1,
                             question: quiz.questions[index],
                             selected: answers[index],
                             revealed: revealAll) { choice in
                    guard answers[index] == nil else { return }
                    let isRight = quiz.questions[index].answerIndex == choice
                    if isRight { Haptics.success() } else { Haptics.warning() }
                    withAnimation(Theme.snappy) { answers[index] = choice }
                }
            }
        }
    }

    /// "3 / 5" on a system fill; green at 12% once every answer is right.
    private var scorePill: some View {
        Text("\(correct) / \(total)")
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(allCorrect ? ResultPalette.good : .secondary)
            .contentTransition(.numericText())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(allCorrect ? ResultPalette.good.opacity(0.12) : Color(uiColor: .tertiarySystemFill), in: Capsule())
            .accessibilityLabel("\(correct) of \(total) correct")
    }
}

private struct QuestionCard: View {
    let number: Int
    let question: Quiz.Question
    let selected: Int?
    let revealed: Bool
    let onSelect: (Int) -> Void

    private var resolved: Bool { selected != nil || revealed }
    private var hasValidAnswer: Bool { question.choices.indices.contains(question.answerIndex) }

    var body: some View {
        ResultCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Question \(number)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                    InlineText(text: question.prompt, font: .headline)
                }

                VStack(spacing: 8) {
                    ForEach(question.choices.indices, id: \.self) { index in
                        ChoiceRow(letter: Self.letter(index),
                                  text: question.choices[index],
                                  state: choiceState(index)) {
                            onSelect(index)
                        }
                        .disabled(resolved)
                    }
                }

                if resolved, let explanation = question.explanation, !explanation.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        InlineText(text: explanation, font: .footnote, color: .secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func choiceState(_ index: Int) -> ChoiceRow.Mode {
        guard resolved else { return .neutral }
        if hasValidAnswer, index == question.answerIndex { return .correct }
        if let selected, selected == index { return .wrong }
        return .dimmed
    }

    private static func letter(_ index: Int) -> String {
        let scalars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return index < scalars.count ? String(scalars[index]) : "\(index + 1)"
    }
}

/// A 44pt choice row: lettered circle, text; green or red 12% fill with a symbol once resolved.
private struct ChoiceRow: View {
    enum Mode { case neutral, correct, wrong, dimmed }

    let letter: String
    let text: String
    let state: Mode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                badge
                Text(InlineMarkdown.attributed(text))
                    .font(.body)
                    .foregroundStyle(state == .dimmed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous))
        }
        .buttonStyle(.plain)
        // The fill, the badge and the text colour all settle with the same spring on resolve.
        .animation(Theme.snappy, value: state)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var badge: some View {
        Group {
            switch state {
            case .correct:
                Image(systemName: "checkmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(ResultPalette.good)
                    .transition(.blurReplace)
            case .wrong:
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(ResultPalette.bad)
                    .transition(.blurReplace)
            case .neutral, .dimmed:
                Text(letter)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .transition(.blurReplace)
            }
        }
        .frame(width: 28, height: 28)
        .background(badgeFill, in: Circle())
    }

    private var badgeFill: Color {
        switch state {
        case .correct: ResultPalette.good.opacity(0.18)
        case .wrong: ResultPalette.bad.opacity(0.18)
        case .neutral, .dimmed: Color(uiColor: .tertiarySystemFill)
        }
    }

    private var background: Color {
        switch state {
        case .correct: ResultPalette.good.opacity(0.12)
        case .wrong: ResultPalette.bad.opacity(0.12)
        case .neutral: Color(uiColor: .tertiarySystemGroupedBackground)
        case .dimmed: Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.6)
        }
    }

    private var accessibilityText: String {
        switch state {
        case .correct: "\(letter), \(text), correct"
        case .wrong: "\(letter), \(text), incorrect"
        case .neutral, .dimmed: "\(letter), \(text)"
        }
    }
}

// MARK: - Slides

struct SlidesArtifactView: View {
    let deck: SlideDeck
    @Environment(\.fuseCompact) private var compact
    @State private var index = 0

    private var slides: [SlideDeck.Slide] { deck.slides }
    private var current: SlideDeck.Slide? { slides[safe: index] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if slides.isEmpty {
                EmptyArtifactCard(text: "No slides were generated.")
            } else {
                TabView(selection: $index) {
                    ForEach(slides.indices, id: \.self) { i in
                        SlideCard(deck: deck, slide: slides[i], number: i + 1, total: slides.count, compact: compact)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .onChange(of: index) { _, _ in Haptics.selection() }

                HStack(spacing: 12) {
                    pageButton(symbol: "chevron.left", label: "Previous slide", disabled: index == 0) {
                        withAnimation(Theme.snappy) { index = max(0, index - 1) }
                    }
                    Spacer(minLength: 0)
                    PageDots(count: slides.count, current: index)
                    Spacer(minLength: 0)
                    pageButton(symbol: "chevron.right", label: "Next slide", disabled: index >= slides.count - 1) {
                        withAnimation(Theme.snappy) { index = min(slides.count - 1, index + 1) }
                    }
                }

                ResultSection(title: "Notes · Slide \(index + 1)") {
                    ResultCard {
                        if let notes = current?.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                            InlineText(text: notes)
                        } else {
                            Text("No notes for this slide.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .animation(nil, value: index)
                }
            }
        }
    }

    private func pageButton(symbol: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(count, 0), id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.primary : Color(uiColor: .tertiaryLabel))
                    .frame(width: 7, height: 7)
            }
        }
        .animation(Theme.snappy, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Slide \(current + 1) of \(count)")
    }
}

/// One 16:10 slide on a grouped card: title, bullets, deck name and page number.
private struct SlideCard: View {
    let deck: SlideDeck
    let slide: SlideDeck.Slide
    let number: Int
    let total: Int
    let compact: Bool

    private var maxBullets: Int { compact ? 4 : 5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(slide.title.isEmpty ? "Slide \(number)" : slide.title)
                .font(compact ? .headline : .title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, compact ? 8 : 12)
            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                ForEach(Array(slide.bullets.prefix(maxBullets).enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(compact ? .footnote : .subheadline)
                            .foregroundStyle(.secondary)
                        Text(InlineMarkdown.attributed(bullet))
                            .font(compact ? .footnote : .subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                }
                if slide.bullets.count > maxBullets {
                    Text("+\(slide.bullets.count - maxBullets) more")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Text(deck.title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(number) / \(total)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(compact ? Theme.margin : Theme.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.groupedCard, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .padding(.horizontal, 1)
    }
}

// MARK: - Checklist

struct ChecklistArtifactView: View {
    let checklist: Checklist
    var showsHeader: Bool = true
    @State private var done: Set<Int> = []

    private var total: Int { checklist.items.count }
    private var complete: Bool { total > 0 && done.count == total }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeader {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(checklist.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text("\(done.count) of \(total)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                    ProgressView(value: total == 0 ? 0 : Double(done.count) / Double(total))
                        .tint(complete ? ResultPalette.good : Color.accentColor)
                        .animation(Theme.snappy, value: done.count)
                }
                .padding(.horizontal, 4)
            }

            ResultCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    if checklist.items.isEmpty {
                        Text("Nothing to check off.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(Theme.margin)
                    }
                    ForEach(checklist.items.indices, id: \.self) { index in
                        let item = checklist.items[index]
                        let isDone = done.contains(index)
                        Button {
                            Haptics.selection()
                            withAnimation(Theme.snappy) {
                                if isDone { done.remove(index) } else { done.insert(index) }
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(isDone ? Color.accentColor : Color(uiColor: .tertiaryLabel))
                                    .contentTransition(.symbolEffect(.replace))
                                    .symbolEffect(.bounce, options: .nonRepeating, value: isDone)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(InlineMarkdown.attributed(item.text))
                                        .font(.body)
                                        .foregroundStyle(isDone ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                                        .strikethrough(isDone)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let detail = item.detail, !detail.isEmpty {
                                        Text(InlineMarkdown.attributed(detail))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, Theme.margin)
                            .padding(.vertical, 10)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isDone ? [.isSelected] : [])

                        if index < total - 1 {
                            Hairline().padding(.leading, Theme.margin + 24 + 12)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            }
        }
    }
}
