import Foundation
import UIKit

// MARK: - Screenshot input
//
// The explicit image handed to the background "Fuse Screens" intent is authoritative: it is
// decoded, orientation-normalized, validated and cropped here, with no Photos or Safari
// fallback. Cropping happens on the full-resolution pixels *before* any downscaling (the
// engine downscales to 1024 on the longest edge when it encodes the request).

/// Which way the two apps were arranged on the captured screen.
enum FuseLayout: String, Codable, CaseIterable, Sendable {
    /// Fold runs top→bottom; the first app is on the left half.
    case leftRight
    /// Fold runs left→right; the first app is on the top half.
    case topBottom
    /// Pick from the aspect ratio: wider than tall → `leftRight`, otherwise `topBottom`.
    case auto

    /// Resolve `auto` for a capture of the given pixel size.
    func resolved(width: Int, height: Int) -> FuseLayout {
        switch self {
        case .leftRight, .topBottom: return self
        case .auto: return width >= height ? .leftRight : .topBottom
        }
    }
}

enum ScreenshotInput {
    enum InputError: LocalizedError, Equatable {
        case undecodable
        case noPixels
        case tooSmall(width: Int, height: Int)
        case zeroSizedCrop

        var errorDescription: String? {
            switch self {
            case .undecodable: return "The screenshot could not be decoded."
            case .noPixels: return "The screenshot has no pixel data."
            case .tooSmall(let w, let h): return "The screenshot is too small to split (\(w)×\(h))."
            case .zeroSizedCrop: return "Splitting the screenshot produced an empty half."
            }
        }
    }

    /// Smallest edge (in pixels) a capture must have before it can be split into two halves.
    static let minimumEdge = 16

    struct Crops {
        var first: UIImage
        var second: UIImage
        /// The layout actually used (never `.auto`).
        var layout: FuseLayout
        var sourceWidth: Int
        var sourceHeight: Int
    }

    // MARK: Decode

    static func decode(_ data: Data) throws -> UIImage {
        guard !data.isEmpty, let image = UIImage(data: data) else { throw InputError.undecodable }
        return image
    }

    // MARK: Orientation

    /// Returns an image whose `cgImage` pixels are in the displayed orientation (`.up`), so pixel
    /// cropping matches what the user saw. Pixel dimensions are preserved.
    static func normalized(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up, image.cgImage != nil { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: Crop

    /// Split the capture into two halves along the fold. Odd edge pixels go to the second half.
    static func crop(_ image: UIImage, layout: FuseLayout) throws -> Crops {
        let upright = normalized(image)
        guard let cg = upright.cgImage else { throw InputError.noPixels }
        let w = cg.width, h = cg.height
        guard w >= minimumEdge, h >= minimumEdge else { throw InputError.tooSmall(width: w, height: h) }

        let resolved = layout.resolved(width: w, height: h)
        let firstRect: CGRect
        let secondRect: CGRect
        switch resolved {
        case .leftRight, .auto:
            let half = w / 2
            firstRect = CGRect(x: 0, y: 0, width: half, height: h)
            secondRect = CGRect(x: half, y: 0, width: w - half, height: h)
        case .topBottom:
            let half = h / 2
            firstRect = CGRect(x: 0, y: 0, width: w, height: half)
            secondRect = CGRect(x: 0, y: half, width: w, height: h - half)
        }
        guard firstRect.width >= 1, firstRect.height >= 1, secondRect.width >= 1, secondRect.height >= 1,
              let a = cg.cropping(to: firstRect), let b = cg.cropping(to: secondRect) else {
            throw InputError.zeroSizedCrop
        }
        return Crops(
            first: UIImage(cgImage: a, scale: upright.scale, orientation: .up),
            second: UIImage(cgImage: b, scale: upright.scale, orientation: .up),
            layout: resolved,
            sourceWidth: w,
            sourceHeight: h
        )
    }

    // MARK: Snapshots

    /// The two `SurfaceSnapshot`s the engine reads for a whole-screen capture.
    static func snapshots(from image: UIImage, layout: FuseLayout) throws -> (left: SurfaceSnapshot, right: SurfaceSnapshot, crops: Crops) {
        let crops = try crop(image, layout: layout)
        let common: [String: String] = [
            "source": "screenshot",
            "layout": crops.layout.rawValue,
            "captureWidth": String(crops.sourceWidth),
            "captureHeight": String(crops.sourceHeight)
        ]
        let left = SurfaceSnapshot(kind: .photo, title: "Left app", image: crops.first, metadata: common)
        let right = SurfaceSnapshot(kind: .photo, title: "Right app", image: crops.second, metadata: common)
        return (left, right, crops)
    }
}
