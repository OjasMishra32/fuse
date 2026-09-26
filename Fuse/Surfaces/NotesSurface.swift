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

/// Plain paper: the editor on the system background, a placeholder, and the character count
/// in a small caption at the bottom right. Paste and clear live in the editor's own edit menu.
struct NotesSurfaceView: View {
    @Bindable var model: NotesSurfaceModel
    @FocusState private var editorFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.ink.ignoresSafeArea()

            TextEditor(text: $model.text)
                .scrollContentBackground(.hidden)
                .font(.body)
                .foregroundStyle(.primary)
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .focused($editorFocused)
                .padding(.horizontal, 11)
                .padding(.top, 8)
                .padding(.bottom, 28)

            if model.text.isEmpty {
                Text("Type or paste anything…")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text(countLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .animation(Theme.snappy, value: model.characterCount)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editorFocused = false }
                    .fontWeight(.semibold)
            }
        }
        .onTapGesture {
            if model.text.isEmpty { editorFocused = true }
        }
    }

    private var countLabel: String {
        let count = model.characterCount
        return count == 1 ? "1 character" : "\(count) characters"
    }
}
