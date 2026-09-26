import Photos
import UIKit

// MARK: - Newest screenshot in the library
//
// Fallback for the "Fuse" intent: if nothing was handed over, use the screenshot the user just
// took of the two apps they had open.

enum LatestScreenshot {
    static func fetch(maxAge: TimeInterval) async -> UIImage? {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }

        func newest(screenshotsOnly: Bool) -> PHAsset? {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = 3
            if screenshotsOnly {
                options.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
            }
            let result = PHAsset.fetchAssets(with: .image, options: options)
            guard let asset = result.firstObject else { return nil }
            if let date = asset.creationDate, Date().timeIntervalSince(date) > maxAge { return nil }
            return asset
        }
        // Real screenshots first; then anything just added (the simulator bridge imports plain PNGs).
        guard let asset = newest(screenshotsOnly: true) ?? newest(screenshotsOnly: false) else { return nil }

        return await withCheckedContinuation { continuation in
            let req = PHImageRequestOptions()
            req.deliveryMode = .highQualityFormat
            req.isNetworkAccessAllowed = true
            req.isSynchronous = false
            var done = false
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: req) { image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if degraded { return }
                guard !done else { return }
                done = true
                continuation.resume(returning: image)
            }
        }
    }
}
