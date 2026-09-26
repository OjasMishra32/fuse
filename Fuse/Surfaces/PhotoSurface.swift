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
    /// Changes even when a replacement photo has the same size and caption.
    private(set) var contentRevision: UInt64 = 0
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
            image: image.fuseDownscaled(maxEdge: 2048),
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
        contentRevision &+= 1
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
        contentRevision &+= 1
        source = newSource
        errorMessage = nil
        isLoading = false
    }

    func clear() {
        Haptics.tap()
        image = nil
        contentRevision &+= 1
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

/// The photo fills the half. A caption field floats at the top; library, camera, paste and
/// remove are glass icon buttons at the bottom center.
struct PhotoSurfaceView: View {
    @Bindable var model: PhotoSurfaceModel
    @FocusState private var captionFocused: Bool

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            if let image = model.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityLabel(model.caption.isEmpty ? "Photo" : model.caption)
            } else {
                ContentUnavailableView {
                    Label("Add a Photo", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("Try your room on one side and furniture on the other, then fold to see them together. Menus, receipts and screenshots work too.")
                }
                .transition(.opacity)
            }

            if model.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding(20)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        }
        .overlay(alignment: .top) {
            if model.hasContent {
                captionField
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if let error = model.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                        .transition(.opacity)
                }
                actions
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Theme.snappy, value: model.hasContent)
        .animation(Theme.snappy, value: model.isLoading)
        .animation(Theme.snappy, value: model.errorMessage)
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

    // MARK: Actions (bottom center)

    private var actions: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                PhotosPicker(selection: $model.pickerItem, matching: .images, photoLibrary: .shared()) {
                    iconLabel("photo.on.rectangle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose from Library")

                if PhotoSurfaceModel.isCameraAvailable {
                    Button {
                        model.openCamera()
                    } label: {
                        iconLabel("camera")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Take Photo")
                }

                Button {
                    model.pasteImage()
                } label: {
                    iconLabel("doc.on.clipboard")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Paste Image")

                if model.hasContent {
                    Button {
                        model.clear()
                    } label: {
                        iconLabel("trash")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove Photo")
                }
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

    // MARK: Caption (top)

    private var captionField: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.quote")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Add a caption", text: $model.caption)
                .font(.subheadline)
                .submitLabel(.done)
                .focused($captionFocused)
                .onSubmit { captionFocused = false }

            if !model.caption.isEmpty {
                Button {
                    model.caption = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .frame(width: 32, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear caption")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .capsule)
    }
}
