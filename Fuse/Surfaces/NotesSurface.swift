import SwiftUI
import UIKit
import Observation

// MARK: - Model

@MainActor
@Observable
final class NotesSurfaceModel: SurfaceModel {
    let kind: SurfaceKind = .notes

    var text: String = ""

    init() {}

    // MARK: Derived

    var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var wordCount: Int {
        trimmed.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var characterCount: Int { text.count }

    var firstLine: String {
        let line = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.trimmingCharacters(in: .whitespaces)
    }

    // MARK: SurfaceModel

    var headline: String {
        let line = firstLine
        guard !line.isEmpty else { return "Notes" }
        return line.count > 40 ? String(line.prefix(40)).trimmingCharacters(in: .whitespaces) + "…" : line
    }

    var hasContent: Bool { !trimmed.isEmpty }

    var thumbnail: UIImage? { nil }

    func capture() async -> SurfaceSnapshot {
        guard hasContent else { return .empty(.notes) }
        let line = firstLine
        let title = line.count > 40 ? String(line.prefix(40)).trimmingCharacters(in: .whitespaces) + "…" : line
        return SurfaceSnapshot(
            kind: .notes,
            title: title.isEmpty ? "Note" : title,
            text: text.fuseClipped(8000),
            image: nil,
            metadata: [
                "words": String(wordCount),
                "characters": String(characterCount)
            ]
        )
    }

    func apply(_ preset: SurfacePreset) {
        switch preset {
        case .text(let value): text = value
        case .url(let url): text = url.absoluteString
        case .document(let url): text = url.lastPathComponent
        case .image, .place: break
        }
    }

    func reset() {
        text = ""
    }

    // MARK: Actions

    func clear() {
        Haptics.tap()
        text = ""
    }

    func pasteFromClipboard() {
        guard let string = UIPasteboard.general.string, !string.isEmpty else {
            Haptics.warning()
            return
        }
        Haptics.soft()
        if trimmed.isEmpty {
            text = string
        } else {
            text += (text.hasSuffix("\n") ? "" : "\n") + string
        }
    }
}

// MARK: - View

struct NotesSurfaceView: View {
    @Bindable var model: NotesSurfaceModel
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(Theme.ink2)

                TextEditor(text: $model.text)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
                    .tint(SurfaceKind.notes.tint)
                    .lineSpacing(4)
                    .scrollIndicators(.hidden)
                    .focused($editorFocused)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 44)

                if model.text.isEmpty {
                    Text("Type or paste anything…")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 15)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }

                footer
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ink)
        .onTapGesture {
            if model.text.isEmpty { editorFocused = true }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "note.text")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SurfaceKind.notes.tint)
                Text(countLabel)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .glassEffect(.regular, in: .capsule)

            Spacer(minLength: 0)

            if editorFocused {
                Button {
                    Haptics.tap()
                    editorFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 30, height: 30)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
            }

            if model.text.isEmpty {
                Button {
                    model.pasteFromClipboard()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Paste")
                            .font(.fuseCaption)
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    model.clear()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Clear")
                            .font(.fuseCaption)
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .animation(Theme.snappy, value: model.text.isEmpty)
        .animation(Theme.snappy, value: editorFocused)
    }

    private var countLabel: String {
        let words = model.wordCount
        if words == 0 { return "Empty" }
        return words == 1 ? "1 word" : "\(words) words"
    }
}
