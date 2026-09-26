import SwiftUI
import PhotosUI
import UIKit
import Observation

// MARK: - Model

@MainActor
@Observable
final class PhotoSurfaceModel: SurfaceModel {
    let kind: SurfaceKind = .photo

    private(set) var image: UIImage?
    private(set) var source: String = ""
    var caption: String = ""
    var pickerItem: PhotosPickerItem?
    var showCamera: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init() {}

    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    // MARK: SurfaceModel

    var headline: String {
        let firstLine = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        if !firstLine.isEmpty { return firstLine.count > 40 ? String(firstLine.prefix(40)) + "…" : firstLine }
        guard let image else { return "Photo" }
        return "Photo \(Int(image.size.width * image.scale))×\(Int(image.size.height * image.scale))"
    }

    var hasContent: Bool { image != nil }

    var thumbnail: UIImage? { image }

    func capture() async -> SurfaceSnapshot {
        guard let image else { return .empty(.photo) }
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let pixelWidth = Int(image.size.width * image.scale)
        let pixelHeight = Int(image.size.height * image.scale)
        var meta: [String: String] = [
            "width": String(pixelWidth),
            "height": String(pixelHeight),
            "source": source.isEmpty ? "unknown" : source
        ]
        if !trimmedCaption.isEmpty { meta["caption"] = trimmedCaption }
        return SurfaceSnapshot(
            kind: .photo,
            title: trimmedCaption.isEmpty ? "Photo" : headline,
            text: trimmedCaption.fuseClipped(2000),
            image: image.fuseDownscaled(maxEdge: 1024),
            metadata: meta
        )
    }

    func apply(_ preset: SurfacePreset) {
        switch preset {
        case .image(let img):
            setImage(img, source: "preset")
        case .text(let text):
            caption = text
        case .url(let url), .document(let url):
            loadTask?.cancel()
            isLoading = true
            loadTask = Task { [weak self] in
                let data = try? Data(contentsOf: url)
                guard let self, !Task.isCancelled else { return }
                self.isLoading = false
                if let data, let img = UIImage(data: data) {
                    self.setImage(img, source: "file")
                } else {
                    self.errorMessage = "Couldn't read an image from that file."
                }
            }
        case .place:
            break
        }
    }

    func reset() {
        loadTask?.cancel()
        image = nil
        caption = ""
        source = ""
        pickerItem = nil
        isLoading = false
        errorMessage = nil
        showCamera = false
    }

    // MARK: Actions

    func setImage(_ newImage: UIImage, source newSource: String) {
        image = newImage.fuseDownscaled(maxEdge: 2048)
        source = newSource
        errorMessage = nil
        isLoading = false
    }

    func clear() {
        Haptics.tap()
        image = nil
        caption = ""
        source = ""
        pickerItem = nil
        errorMessage = nil
    }

    /// Called by the view whenever the PhotosPicker selection changes.
    func handlePickerItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil
        loadTask = Task { [weak self] in
            let data = try? await item.loadTransferable(type: Data.self)
            guard let self, !Task.isCancelled else { return }
            if let data, let img = UIImage(data: data) {
                Haptics.soft()
                self.setImage(img, source: "library")
            } else {
                self.isLoading = false
                self.errorMessage = "That item couldn't be loaded as an image."
            }
            self.pickerItem = nil
        }
    }

    func pasteImage() {
        let board = UIPasteboard.general
        if board.hasImages, let img = board.image {
            Haptics.success()
            setImage(img, source: "clipboard")
        } else if board.hasURLs, let url = board.url, let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
            Haptics.success()
            setImage(img, source: "clipboard")
        } else {
            Haptics.warning()
            errorMessage = "No image on the clipboard."
        }
    }

    func openCamera() {
        guard Self.isCameraAvailable else {
            errorMessage = "No camera on this device."
            return
        }
        Haptics.tap()
        showCamera = true
    }

    func cameraDidCapture(_ img: UIImage?) {
        showCamera = false
        guard let img else { return }
        Haptics.success()
        setImage(img, source: "camera")
    }
}

// MARK: - Camera

private struct CameraPicker: UIViewControllerRepresentable {
    var onFinish: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        picker.overrideUserInterfaceStyle = .dark
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        context.coordinator.onFinish = onFinish
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            onFinish(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

// MARK: - View

struct PhotoSurfaceView: View {
    @Bindable var model: PhotoSurfaceModel
    @FocusState private var captionFocused: Bool

    var body: some View {
        ZStack {
            Theme.ink2.ignoresSafeArea()

            if let image = model.image {
                photoContent(image)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                emptyState
                    .transition(.opacity)
            }

            if model.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .tint(SurfaceKind.photo.tint)
                    .padding(20)
                    .glassEffect(.regular, in: .rect(cornerRadius: Theme.radiusCard))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ink.ignoresSafeArea())
        .animation(Theme.snappy, value: model.hasContent)
        .animation(Theme.snappy, value: model.isLoading)
        .onChange(of: model.pickerItem) { _, item in
            model.handlePickerItem(item)
        }
        .fullScreenCover(isPresented: $model.showCamera) {
            CameraPicker { image in
                model.cameraDidCapture(image)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 18) {
            SurfaceEmptyState(
                symbol: "photo.on.rectangle.angled",
                title: "Add a photo",
                hint: "A menu, a whiteboard, a receipt, a screenshot — anything the other screen should know about.",
                tint: SurfaceKind.photo.tint
            )
            .frame(maxHeight: 200)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    PhotosPicker(selection: $model.pickerItem, matching: .images, photoLibrary: .shared()) {
                        pickerLabel("Library", symbol: "photo.on.rectangle")
                    }
                    .buttonStyle(.plain)

                    if PhotoSurfaceModel.isCameraAvailable {
                        GlassButton(title: "Camera", symbol: "camera") {
                            model.openCamera()
                        }
                    }
                }

                GlassButton(title: "Paste image", symbol: "doc.on.clipboard") {
                    model.pasteImage()
                }
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Theme.snappy, value: model.errorMessage)
    }

    private func pickerLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
            Text(title).font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    // MARK: Photo

    private func photoContent(_ image: UIImage) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(10)

                HStack(spacing: 6) {
                    PhotosPicker(selection: $model.pickerItem, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 30, height: 30)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)

                    if PhotoSurfaceModel.isCameraAvailable {
                        GlassIconButton(symbol: "camera", size: 30) {
                            model.openCamera()
                        }
                    }

                    GlassIconButton(symbol: "xmark", size: 30) {
                        model.clear()
                    }
                }
                .padding(16)
            }

            captionField
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
    }

    private var captionField: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.quote")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(captionFocused || !model.caption.isEmpty ? SurfaceKind.photo.tint : Theme.textTertiary)

            TextField("Add a caption (optional)", text: $model.caption)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .tint(SurfaceKind.photo.tint)
                .submitLabel(.done)
                .focused($captionFocused)
                .onSubmit { captionFocused = false }

            if !model.caption.isEmpty {
                Button {
                    model.caption = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .capsule)
    }
}
