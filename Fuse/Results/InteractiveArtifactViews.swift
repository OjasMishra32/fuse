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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ResultCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(quiz.title)
                            .font(.fuseHeadline)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        Text("\(correct) / \(total)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(correct == total && total > 0 ? ResultPalette.good : Theme.textSecondary)
                            .contentTransition(.numericText())
                    }
                    ProgressBar(fraction: total == 0 ? 0 : Double(answered) / Double(total))
                    HStack {
                        Text(answered == total && total > 0 ? "All answered" : "\(answered) of \(total) answered")
                            .font(.fuseCaption)
                            .foregroundStyle(Theme.textTertiary)
                        Spacer()
                        if answered > 0 || revealAll {
                            MiniButton(title: "Reset", symbol: "arrow.counterclockwise") {
                                Haptics.tap()
                                withAnimation(Theme.snappy) { answers.removeAll(); revealAll = false }
                            }
                        }
                        MiniButton(title: revealAll ? "Hide answers" : "Reveal all", symbol: revealAll ? "eye.slash" : "eye") {
                            Haptics.tap()
                            withAnimation(Theme.snappy) { revealAll.toggle() }
                        }
                    }
                }
            }

            if quiz.questions.isEmpty {
                ResultCard {
                    Text("No questions were generated.")
                        .font(.fuseBody)
                        .foregroundStyle(Theme.textSecondary)
                }
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
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("Q\(number)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.violet)
                    InlineText(text: question.prompt, font: .fuseHeadline)
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
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                        InlineText(text: explanation, font: .fuseCaption, color: Theme.textSecondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

private struct ChoiceRow: View {
    enum Mode { case neutral, correct, wrong, dimmed }

    let letter: String
    let text: String
    let state: Mode
    let action: () -> Void

    private var tint: Color {
        switch state {
        case .correct: ResultPalette.good
        case .wrong: ResultPalette.bad
        case .neutral, .dimmed: Theme.textSecondary
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                ZStack {
                    Circle().fill(state == .neutral || state == .dimmed ? Color.white.opacity(0.06) : tint.opacity(0.2))
                    switch state {
                    case .correct:
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(tint)
                    case .wrong:
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(tint)
                    case .neutral, .dimmed:
                        Text(letter).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: 26, height: 26)

                Text(InlineMarkdown.attributed(text))
                    .font(.fuseBody)
                    .foregroundStyle(state == .dimmed ? Theme.textTertiary : Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        switch state {
        case .correct: ResultPalette.good.opacity(0.14)
        case .wrong: ResultPalette.bad.opacity(0.14)
        case .neutral: Color.white.opacity(0.04)
        case .dimmed: Color.white.opacity(0.02)
        }
    }

    private var border: Color {
        switch state {
        case .correct: ResultPalette.good.opacity(0.45)
        case .wrong: ResultPalette.bad.opacity(0.45)
        case .neutral, .dimmed: Theme.line
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
        VStack(alignment: .leading, spacing: 14) {
            if slides.isEmpty {
                ResultCard {
                    Text("No slides were generated.")
                        .font(.fuseBody)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                TabView(selection: $index) {
                    ForEach(slides.indices, id: \.self) { i in
                        SlideCard(deck: deck, slide: slides[i], number: i + 1, total: slides.count, compact: compact)
                            .padding(.horizontal, 2)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: compact ? 225 : 300)
                .onChange(of: index) { _, _ in Haptics.selection() }

                HStack(spacing: 12) {
                    GlassIconButton(symbol: "chevron.left", size: 30) {
                        withAnimation(Theme.snappy) { index = max(0, index - 1) }
                    }
                    .opacity(index == 0 ? 0.35 : 1)
                    .disabled(index == 0)

                    Spacer(minLength: 0)
                    PageDots(count: slides.count, current: index)
                    Spacer(minLength: 0)

                    GlassIconButton(symbol: "chevron.right", size: 30) {
                        withAnimation(Theme.snappy) { index = min(slides.count - 1, index + 1) }
                    }
                    .opacity(index >= slides.count - 1 ? 0.35 : 1)
                    .disabled(index >= slides.count - 1)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Speaker notes · Slide \(index + 1)")
                    ResultCard {
                        if let notes = current?.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                            InlineText(text: notes, color: Theme.textPrimary.opacity(0.9))
                        } else {
                            Text("No notes for this slide.")
                                .font(.fuseBody)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .animation(nil, value: index)
                }
            }
        }
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(count, 0), id: \.self) { i in
                Capsule()
                    .fill(i == current ? Theme.textPrimary : Color.white.opacity(0.2))
                    .frame(width: i == current ? 16 : 5, height: 5)
            }
        }
        .animation(Theme.snappy, value: current)
    }
}

private struct SlideCard: View {
    let deck: SlideDeck
    let slide: SlideDeck.Slide
    let number: Int
    let total: Int
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(slide.title.isEmpty ? "Slide \(number)" : slide.title)
                .font(.system(size: compact ? 17 : 21, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(Theme.energy)
                .frame(width: 36, height: 2)
                .padding(.top, 8)
                .padding(.bottom, 10)
            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                ForEach(Array(slide.bullets.prefix(6).enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("–")
                            .font(.system(size: compact ? 12.5 : 14, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                        Text(InlineMarkdown.attributed(bullet))
                            .font(.system(size: compact ? 12.5 : 14))
                            .foregroundStyle(Theme.textPrimary.opacity(0.86))
                            .lineLimit(2)
                    }
                }
                if slide.bullets.count > 6 {
                    Text("+\(slide.bullets.count - 6) more")
                        .font(.fuseCaption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Text(deck.title)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                Spacer()
                Text("\(number) / \(total)")
                    .font(.fuseMono)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(compact ? 16 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .background(Theme.ink2, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

// MARK: - Checklist

struct ChecklistArtifactView: View {
    let checklist: Checklist
    var showsHeader: Bool = true
    @State private var done: Set<Int> = []

    private var total: Int { checklist.items.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeader {
                HStack(alignment: .firstTextBaseline) {
                    Text(checklist.title)
                        .font(.fuseHeadline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text("\(done.count) of \(total)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(done.count == total && total > 0 ? ResultPalette.good : Theme.textSecondary)
                        .contentTransition(.numericText())
                }
                ProgressBar(fraction: total == 0 ? 0 : Double(done.count) / Double(total),
                            tint: done.count == total && total > 0 ? ResultPalette.good : Theme.violet)
            }

            ResultCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    if checklist.items.isEmpty {
                        Text("Nothing to check off.")
                            .font(.fuseBody)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(16)
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
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundStyle(isDone ? ResultPalette.good : Theme.textTertiary)
                                    .contentTransition(.symbolEffect(.replace))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(InlineMarkdown.attributed(item.text))
                                        .font(.fuseBody)
                                        .foregroundStyle(isDone ? Theme.textTertiary : Theme.textPrimary)
                                        .strikethrough(isDone, color: Theme.textTertiary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let detail = item.detail, !detail.isEmpty {
                                        Text(InlineMarkdown.attributed(detail))
                                            .font(.fuseCaption)
                                            .foregroundStyle(Theme.textSecondary)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < total - 1 {
                            Hairline().padding(.leading, 46)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            }
        }
    }
}
