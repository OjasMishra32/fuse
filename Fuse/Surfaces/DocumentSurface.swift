import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import UIKit
import Observation

// MARK: - Model

@MainActor
@Observable
final class DocumentSurfaceModel: SurfaceModel {
    let kind: SurfaceKind = .document

    enum Content {
        case pdf(PDFDocument)
        case text(String)
        case image(UIImage)

        var typeKey: String {
            switch self {
            case .pdf: "pdf"
            case .text: "text"
            case .image: "image"
            }
        }
    }

    static let allowedTypes: [UTType] = [.pdf, .plainText, .sourceCode, .json, .rtf, .utf8PlainText, .image, .text]

    private(set) var content: Content?
    private(set) var filename: String = ""
    private(set) var typeLabel: String = ""
    private(set) var pageCount: Int = 0
    private(set) var localURL: URL?
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var previewImage: UIImage?
    var showImporter: Bool = false

    @ObservationIgnored private var extractedText: String?
    @ObservationIgnored private var extractionTask: Task<Void, Never>?

    init() {}

    // MARK: SurfaceModel

    var headline: String {
        if !filename.isEmpty { return filename }
        return content == nil ? "Files" : "Untitled"
    }

    var hasContent: Bool { content != nil }

    var thumbnail: UIImage? {
        if case .image(let image) = content { return image }
        return previewImage
    }

    func capture() async -> SurfaceSnapshot {
        guard let content else { return .empty(.document) }
        let title = filename.isEmpty ? "Untitled" : filename
        var meta: [String: String] = [
            "filename": title,
            "pages": String(max(pageCount, 1)),
            "type": typeLabel.isEmpty ? content.typeKey : typeLabel.lowercased()
        ]

        switch content {
        case .pdf(let document):
            let text = await pdfText(for: document)
            let image = document.page(at: 0)?.thumbnail(of: CGSize(width: 1024, height: 1024), for: .mediaBox)
            if let attrs = document.documentAttributes {
                if let docTitle = attrs[PDFDocumentAttribute.titleAttribute] as? String, !docTitle.isEmpty { meta["documentTitle"] = docTitle }
                if let author = attrs[PDFDocumentAttribute.authorAttribute] as? String, !author.isEmpty { meta["author"] = author }
            }
            meta["characters"] = String(text.count)
            return SurfaceSnapshot(
                kind: .document,
                title: title,
                text: text.fuseCollapsedWhitespace.fuseClipped(8000),
                image: image?.fuseDownscaled(maxEdge: 1024),
                metadata: meta
            )

        case .text(let text):
            meta["characters"] = String(text.count)
            meta["lines"] = String(text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count)
            return SurfaceSnapshot(
                kind: .document,
                title: title,
                text: text.fuseClipped(8000),
                image: nil,
                metadata: meta
            )

        case .image(let image):
            meta["width"] = String(Int(image.size.width * image.scale))
            meta["height"] = String(Int(image.size.height * image.scale))
            return SurfaceSnapshot(
                kind: .document,
                title: title,
                text: "",
                image: image.fuseDownscaled(maxEdge: 1024),
                metadata: meta
            )
        }
    }

    func apply(_ preset: SurfacePreset) {
        switch preset {
        case .document(let url):
            importFile(from: url)
        case .url(let url):
            if url.isFileURL { importFile(from: url) }
        case .text(let text):
            showText(text, filename: "Untitled.txt")
        case .image(let image):
            clearState()
            content = .image(image)
            filename = "Image"
            typeLabel = "IMAGE"
            pageCount = 1
        case .place:
            break
        }
    }

    func reset() {
        clearState()
        showImporter = false
    }

    // MARK: Actions

    func chooseFile() {
        Haptics.tap()
        showImporter = true
    }

    func clear() {
        Haptics.tap()
        clearState()
    }

    func pasteText() {
        guard let string = UIPasteboard.general.string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Haptics.warning()
            errorMessage = "No text on the clipboard."
            return
        }
        Haptics.success()
        showText(string, filename: "Pasted.txt")
    }

    func showText(_ text: String, filename name: String) {
        clearState()
        content = .text(text)
        extractedText = text
        filename = name
        typeLabel = (name as NSString).pathExtension.uppercased().isEmpty ? "TEXT" : (name as NSString).pathExtension.uppercased()
        pageCount = 1
    }

    /// Copies a picked (possibly security-scoped) file into the app's tmp directory and loads it.
    func importFile(from pickedURL: URL) {
        errorMessage = nil
        isLoading = true
        let scoped = pickedURL.startAccessingSecurityScopedResource()
        defer { if scoped { pickedURL.stopAccessingSecurityScopedResource() } }

        do {
            let local = try Self.copyToTemporary(pickedURL)
            try load(localURL: local)
        } catch {
            isLoading = false
            Haptics.warning()
            errorMessage = "Couldn't open \(pickedURL.lastPathComponent). \(error.localizedDescription)"
        }
    }

    func importerFailed(_ error: Error) {
        isLoading = false
        errorMessage = error.localizedDescription
    }

    // MARK: Loading

    private func load(localURL url: URL) throws {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let type = UTType(filenameExtension: ext) ?? .data

        clearState()
        localURL = url
        filename = name
        typeLabel = ext.isEmpty ? type.preferredFilenameExtension?.uppercased() ?? "FILE" : ext.uppercased()

        if type.conforms(to: .pdf) {
            guard let document = PDFDocument(url: url) else { throw DocumentError.unreadable }
            content = .pdf(document)
            pageCount = document.pageCount
            previewImage = document.page(at: 0)?.thumbnail(of: CGSize(width: 480, height: 480), for: .mediaBox)
            isLoading = false
            extractionTask = Task { [weak self] in
                let text = await Task.detached(priority: .userInitiated) {
                    PDFDocument(url: url)?.string ?? ""
                }.value
                guard let self, !Task.isCancelled, self.localURL == url else { return }
                self.extractedText = text
            }
        } else if type.conforms(to: .image) {
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { throw DocumentError.unreadable }
            content = .image(image.fuseDownscaled(maxEdge: 2048))
            pageCount = 1
            isLoading = false
        } else if type.conforms(to: .rtf) || ext == "rtf" {
            let attributed = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            content = .text(attributed.string)
            extractedText = attributed.string
            pageCount = 1
            isLoading = false
        } else {
            let text = try Self.readText(at: url)
            content = .text(text)
            extractedText = text
            pageCount = 1
            isLoading = false
        }
        Haptics.soft()
    }

    private func pdfText(for document: PDFDocument) async -> String {
        if let extractedText { return extractedText }
        let url = localURL
        let text = await Task.detached(priority: .userInitiated) { () -> String in
            if let url, let doc = PDFDocument(url: url) { return doc.string ?? "" }
            return ""
        }.value
        if !text.isEmpty { extractedText = text; return text }
        return document.string ?? ""
    }

    private func clearState() {
        extractionTask?.cancel()
        extractionTask = nil
        content = nil
        filename = ""
        typeLabel = ""
        pageCount = 0
        localURL = nil
        isLoading = false
        errorMessage = nil
        previewImage = nil
        extractedText = nil
    }

    enum DocumentError: LocalizedError {
        case unreadable
        case notText

        var errorDescription: String? {
            switch self {
            case .unreadable: "The file couldn't be read."
            case .notText: "The file isn't a text document."
            }
        }
    }

    private static func copyToTemporary(_ source: URL) throws -> URL {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory
            .appendingPathComponent("FuseDocuments", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let destination = dir.appendingPathComponent(source.lastPathComponent)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
        return destination
    }

    private static func readText(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .utf16) { return text }
        if let text = String(data: data, encoding: .isoLatin1) { return text }
        // Binary check: too many NULs means this isn't text.
        let sample = data.prefix(4096)
        let nulRatio = Double(sample.filter { $0 == 0 }.count) / Double(max(sample.count, 1))
        if nulRatio > 0.05 { throw DocumentError.notText }
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - PDF view

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.pageShadowsEnabled = false
        view.backgroundColor = UIColor(Theme.ink2)
        view.pageBreakMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        view.document = document
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
            uiView.autoScales = true
        }
    }
}

// MARK: - View

struct DocumentSurfaceView: View {
    @Bindable var model: DocumentSurfaceModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .fill(Theme.ink2)

            if let content = model.content {
                documentContent(content)
                    .transition(.opacity)
            } else {
                emptyState
                    .transition(.opacity)
            }

            if model.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .tint(SurfaceKind.document.tint)
                    .padding(20)
                    .glassEffect(.regular, in: .rect(cornerRadius: Theme.radiusCard))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ink)
        .animation(Theme.snappy, value: model.hasContent)
        .fileImporter(
            isPresented: $model.showImporter,
            allowedContentTypes: DocumentSurfaceModel.allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { model.importFile(from: url) }
            case .failure(let error):
                model.importerFailed(error)
            }
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 18) {
            SurfaceEmptyState(
                symbol: "doc.text.magnifyingglass",
                title: "Open a file",
                hint: "PDFs, text, code, JSON or images from Files. The other screen gets to read it.",
                tint: SurfaceKind.document.tint
            )
            .frame(maxHeight: 200)

            HStack(spacing: 8) {
                EnergyButton(title: "Choose file", symbol: "folder") {
                    model.chooseFile()
                }
                GlassButton(title: "Paste text", symbol: "doc.on.clipboard") {
                    model.pasteText()
                }
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Theme.snappy, value: model.errorMessage)
    }

    // MARK: Content

    private func documentContent(_ content: DocumentSurfaceModel.Content) -> some View {
        VStack(spacing: 0) {
            header(for: content)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Group {
                switch content {
                case .pdf(let document):
                    PDFKitView(document: document)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)

                case .text(let text):
                    ScrollView([.vertical, .horizontal]) {
                        Text(text)
                            .font(.fuseMono)
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(2)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    .scrollIndicators(.hidden)
                    .background(Theme.ink3.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)

                case .image(let image):
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func header(for content: DocumentSurfaceModel.Content) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol(for: content))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SurfaceKind.document.tint)
                .frame(width: 30, height: 30)
                .background(SurfaceKind.document.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(model.filename.isEmpty ? "Untitled" : model.filename)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle(for: content))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer(minLength: 4)

            GlassIconButton(symbol: "folder", size: 30) {
                model.chooseFile()
            }
            GlassIconButton(symbol: "xmark", size: 30) {
                model.clear()
            }
        }
    }

    private func symbol(for content: DocumentSurfaceModel.Content) -> String {
        switch content {
        case .pdf: "doc.richtext"
        case .text: "doc.plaintext"
        case .image: "photo"
        }
    }

    private func subtitle(for content: DocumentSurfaceModel.Content) -> String {
        switch content {
        case .pdf:
            let pages = model.pageCount
            return "\(model.typeLabel) · \(pages == 1 ? "1 page" : "\(pages) pages")"
        case .text(let text):
            let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
            return "\(model.typeLabel) · \(lines == 1 ? "1 line" : "\(lines) lines")"
        case .image(let image):
            return "\(model.typeLabel) · \(Int(image.size.width * image.scale)) × \(Int(image.size.height * image.scale))"
        }
    }
}
