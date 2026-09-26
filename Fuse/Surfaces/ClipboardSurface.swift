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

struct ClipboardSurfaceView: View {
    let model: ClipboardSurfaceModel

    var body: some View {
        ZStack {
            Theme.ink2.ignoresSafeArea()

            if let content = model.content {
                contentView(content)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                emptyState
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ink.ignoresSafeArea())
        .animation(Theme.snappy, value: model.hasContent)
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 22) {
            SurfaceEmptyState(
                symbol: "doc.on.clipboard",
                title: "Bring in your clipboard",
                hint: "Text, a link or an image you've copied anywhere on your phone.",
                tint: SurfaceKind.clipboard.tint
            )
            .frame(maxHeight: 200)

            Button {
                model.pasteFromClipboard()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Paste from clipboard")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.black.opacity(0.9))
                .padding(.horizontal, 24)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(colors: [SurfaceKind.clipboard.tint, Theme.cyan], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
                .shadow(color: Theme.cyan.opacity(0.35), radius: 16, y: 8)
            }
            .buttonStyle(.plain)

            if let message = model.lastMessage {
                Text(message)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Theme.snappy, value: model.lastMessage)
    }

    // MARK: Content

    @ViewBuilder
    private func contentView(_ content: ClipboardSurfaceModel.Content) -> some View {
        VStack(spacing: 0) {
            header(for: content)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            switch content {
            case .text(let text):
                ScrollView {
                    Text(text)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                }
                .scrollIndicators(.hidden)

            case .url(let url):
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(SurfaceKind.clipboard.tint)
                            .frame(width: 36, height: 36)
                            .background(SurfaceKind.clipboard.tint.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.host ?? "Link")
                                .font(.fuseHeadline)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text(url.absoluteString)
                                .font(.fuseCaption)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(3)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.ink3, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            case .image(let image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
    }

    private func header(for content: ClipboardSurfaceModel.Content) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: symbol(for: content))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SurfaceKind.clipboard.tint)
                Text(label(for: content))
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .glassEffect(.regular, in: .capsule)

            Spacer(minLength: 0)

            Button {
                model.pasteFromClipboard()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 30, height: 30)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)

            Button {
                model.clear()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 30, height: 30)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
        }
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
