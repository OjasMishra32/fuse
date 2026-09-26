import UIKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Send to Fuse
//
// A share-sheet extension. From any app: Share → Fuse → pick a half. The item lands on that
// half of the phone; fold to fuse it with whatever is on the other half.

@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private var payload = SharedPayload()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await loadAttachments(); present() }
    }

    private func present() {
        let host = UIHostingController(rootView: ShareView(payload: payload) { [weak self] side in
            self?.deliver(to: side)
        } onCancel: { [weak self] in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "fuse.share", code: 0))
        })
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private func loadAttachments() async {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        for item in items {
            if let title = item.attributedContentText?.string, !title.isEmpty { payload.text = title }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                    if url.isFileURL { payload.fileURL = url } else { payload.url = url }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    if let data = try? await loadImageData(provider) { payload.imageData = data }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier),
                          let url = try? await provider.loadItem(forTypeIdentifier: UTType.pdf.identifier) as? URL {
                    payload.fileURL = url
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    payload.text = text
                }
            }
        }
    }

    private func loadImageData(_ provider: NSItemProvider) async throws -> Data? {
        let item = try await provider.loadItem(forTypeIdentifier: UTType.image.identifier)
        if let url = item as? URL { return try Data(contentsOf: url) }
        if let image = item as? UIImage { return image.jpegData(compressionQuality: 0.85) }
        if let data = item as? Data { return data }
        return nil
    }

    private func deliver(to side: SharedInbox.Item.Side) {
        var item: SharedInbox.Item
        if let data = payload.imageData, let name = SharedInbox.store(data: data, preferredName: "photo.jpg") {
            item = .init(side: side, kind: .image, title: "Photo", fileName: name)
        } else if let file = payload.fileURL {
            let accessing = file.startAccessingSecurityScopedResource()
            defer { if accessing { file.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: file), let name = SharedInbox.store(data: data, preferredName: file.lastPathComponent) {
                item = .init(side: side, kind: .file, title: file.lastPathComponent, fileName: name)
            } else {
                item = .init(side: side, kind: .text, title: "Shared", text: payload.text ?? file.lastPathComponent)
            }
        } else if let url = payload.url {
            item = .init(side: side, kind: .url, title: url.host ?? "Link", url: url.absoluteString)
        } else {
            item = .init(side: side, kind: .text, title: "Text", text: payload.text ?? "")
        }
        SharedInbox.enqueue(item)
        openFuse()
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// Ask the system to bring Fuse to the front. Falls back silently; the item waits in the inbox.
    private func openFuse() {
        guard let url = URL(string: "fuse://inbox") else { return }
        var responder: UIResponder? = self
        while let r = responder {
            if r.responds(to: NSSelectorFromString("openURL:")) {
                _ = r.perform(NSSelectorFromString("openURL:"), with: url)
                return
            }
            responder = r.next
        }
    }
}

struct SharedPayload {
    var url: URL?
    var text: String?
    var imageData: Data?
    var fileURL: URL?

    var summary: String {
        if imageData != nil { return "Photo" }
        if let fileURL { return fileURL.lastPathComponent }
        if let url { return url.absoluteString }
        return text ?? ""
    }
    var symbol: String {
        if imageData != nil { return "photo" }
        if fileURL != nil { return "doc" }
        if url != nil { return "safari" }
        return "text.alignleft"
    }
}

struct ShareView: View {
    var payload: SharedPayload
    var onPick: (SharedInbox.Item.Side) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: payload.symbol)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 36)
                    Text(payload.summary)
                        .font(.subheadline)
                        .lineLimit(3)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("Which half of the phone?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    halfButton("Left screen", symbol: "rectangle.lefthalf.inset.filled") { onPick(.left) }
                    halfButton("Right screen", symbol: "rectangle.righthalf.inset.filled") { onPick(.right) }
                }
                Spacer()
            }
            .padding(20)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Send to Fuse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
            }
        }
    }

    private func halfButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title)
                Text(title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 14))
    }
}
