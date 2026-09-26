import SwiftUI
import UIKit
import Observation

// MARK: - Model

@MainActor
@Observable
final class ClipboardSurfaceModel: SurfaceModel {
    let kind: SurfaceKind = .clipboard

    enum Content {
        case text(String)
        case url(URL)
        case image(UIImage)
    }

    private(set) var content: Content?
    private(set) var pastedAt: Date?
    private(set) var lastMessage: String?

    init() {}

    // MARK: SurfaceModel

    var headline: String {
        switch content {
        case .text(let text):
            let line = text.fuseCollapsedWhitespace.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Text"
            return line.count > 40 ? String(line.prefix(40)) + "…" : line
        case .url(let url):
            return url.host ?? url.absoluteString
        case .image(let image):
            return "Image \(Int(image.size.width))×\(Int(image.size.height))"
        case nil:
            return "Clipboard"
        }
    }

    var hasContent: Bool { content != nil }

    var thumbnail: UIImage? {
        if case .image(let image) = content { return image }
        return nil
    }

    func capture() async -> SurfaceSnapshot {
        guard let content else { return .empty(.clipboard) }
        switch content {
        case .text(let text):
            let cleaned = text.fuseCollapsedWhitespace
            return SurfaceSnapshot(
                kind: .clipboard,
                title: headline,
                text: cleaned.fuseClipped(8000),
                image: nil,
                metadata: ["type": "text", "characters": String(text.count)]
            )
        case .url(let url):
            return SurfaceSnapshot(
                kind: .clipboard,
                title: headline,
                text: url.absoluteString,
                image: nil,
                metadata: ["type": "url", "url": url.absoluteString]
            )
        case .image(let image):
            return SurfaceSnapshot(
                kind: .clipboard,
                title: headline,
                text: "",
                image: image.fuseDownscaled(maxEdge: 1024),
                metadata: [
                    "type": "image",
                    "width": String(Int(image.size.width * image.scale)),
                    "height": String(Int(image.size.height * image.scale))
                ]
            )
        }
    }

    func apply(_ preset: SurfacePreset) {
        switch preset {
        case .text(let text):
            if let url = ClipboardSurfaceModel.urlIfBare(text) {
                content = .url(url)
            } else {
                content = .text(text)
            }
            pastedAt = .now
        case .url(let url):
            content = .url(url)
            pastedAt = .now
        case .image(let image):
            content = .image(image)
            pastedAt = .now
        case .document(let url):
            content = .url(url)
            pastedAt = .now
        case .place:
            break
        }
        lastMessage = nil
    }

    func reset() {
        content = nil
        pastedAt = nil
        lastMessage = nil
    }

    // MARK: Actions

    /// Reads the system pasteboard. Only ever called from a user tap, so the paste banner is expected.
    func pasteFromClipboard() {
        let board = UIPasteboard.general
        if board.hasImages, let image = board.image {
            content = .image(image)
        } else if board.hasURLs, let url = board.url, !(board.hasStrings && (board.string?.contains(where: \.isWhitespace) ?? false)) {
            content = .url(url)
        } else if board.hasStrings, let string = board.string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let url = ClipboardSurfaceModel.urlIfBare(string) {
                content = .url(url)
            } else {
                content = .text(string)
            }
        } else {
            Haptics.warning()
            lastMessage = "Nothing to paste. Copy some text, a link or an image first."
            return
        }
        Haptics.success()
        lastMessage = nil
        pastedAt = .now
    }

    func clear() {
        Haptics.tap()
        content = nil
        pastedAt = nil
        lastMessage = nil
    }

    private static func urlIfBare(_ string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return nil }
        return url
    }
}

// MARK: - View

/// One Paste button while empty; whatever was pasted fills the half after, under a small pill
/// that says what it is.
struct ClipboardSurfaceView: View {
    let model: ClipboardSurfaceModel

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            if let content = model.content {
                VStack(spacing: 0) {
                    header(for: content)
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                    body(for: content)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(edges: [.horizontal, .bottom])
                }
                .transition(.opacity)
            } else {
                emptyState
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Theme.snappy, value: model.hasContent)
    }

    // MARK: Empty

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Bring In Your Clipboard", systemImage: "doc.on.clipboard")
        } description: {
            Text("Text, a link or an image you've copied anywhere on your phone.")
        } actions: {
            VStack(spacing: 8) {
                Button {
                    model.pasteFromClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

                if let message = model.lastMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 260)
                        .padding(.top, 4)
                        .transition(.opacity)
                }
            }
            .animation(Theme.snappy, value: model.lastMessage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Content

    @ViewBuilder
    private func body(for content: ClipboardSurfaceModel.Content) -> some View {
        switch content {
        case .text(let text):
            ScrollView {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.margin)
                    .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, 34, for: .scrollContent)

        case .url(let url):
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text(url.host ?? "Link")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(url.absoluteString)
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.margin)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)

        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Pasted image")
        }
    }

    // MARK: Pill (top)

    private func header(for content: ClipboardSurfaceModel.Content) -> some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: symbol(for: content))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(label(for: content))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .capsule)
                .accessibilityElement(children: .combine)

                Button {
                    model.pasteFromClipboard()
                } label: {
                    iconLabel("doc.on.clipboard")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Paste Again")

                Button {
                    model.clear()
                } label: {
                    iconLabel("xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
    }

    private func iconLabel(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive(), in: .circle)
    }

    private func symbol(for content: ClipboardSurfaceModel.Content) -> String {
        switch content {
        case .text: "text.alignleft"
        case .url: "link"
        case .image: "photo"
        }
    }

    private func label(for content: ClipboardSurfaceModel.Content) -> String {
        switch content {
        case .text(let text):
            let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            return words == 1 ? "1 word" : "\(words) words"
        case .url:
            return "Link"
        case .image(let image):
            return "\(Int(image.size.width * image.scale)) × \(Int(image.size.height * image.scale))"
        }
    }
}
