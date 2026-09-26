import AVKit
import AVFoundation
import CoreMedia
import CoreVideo
import UIKit

// MARK: - FloatingOrb
//
// A Fuse presence that floats over every other app. It uses the system's
// picture-in-picture window with a sample-buffer layer we draw into ourselves, so it
// survives while Safari, Maps or anything else is in front:
//   • the window shows what Fuse would do with what you're reading
//   • tapping its pause button asks Fuse to fuse, in the background
//   • the result summary is drawn into the window; tapping "return" opens the full result
// Nothing here is a screenshot; the inputs come from the Safari extension's recents.

@MainActor
final class FloatingOrb: NSObject {
    static let shared = FloatingOrb()

    /// The user tapped the window's action (pause) button.
    var onTrigger: (() -> Void)?
    /// The user asked to return to the app from the window.
    var onRestore: (() -> Void)?
    /// Supplies the idle headline/detail on every frame (recent pages change while Safari is in front).
    var statusProvider: (() -> (String, String))?

    private(set) var isActive = false
    private var controller: AVPictureInPictureController?
    private let displayLayer = AVSampleBufferDisplayLayer()
    private var hostView: UIView?
    private var timer: Timer?
    private var frame: Int64 = 0

    private var headline = "Fuse"
    private var detail = "Read two things, then tap ⏸"
    private var busy = false

    var isSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }

    // MARK: Lifecycle

    /// Call once with the app's window. The window auto-starts the moment the app leaves the foreground.
    func attach(to window: UIWindow) {
        guard controller == nil, isSupported else { return }
        let host = UIView(frame: CGRect(x: 0, y: window.bounds.height - 3, width: 2, height: 2))
        host.isUserInteractionEnabled = false
        host.backgroundColor = .clear
        displayLayer.frame = host.bounds
        displayLayer.videoGravity = .resizeAspect
        host.layer.addSublayer(displayLayer)
        window.addSubview(host)
        hostView = host

        let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: displayLayer, playbackDelegate: self)
        let pip = AVPictureInPictureController(contentSource: source)
        pip.delegate = self
        pip.canStartPictureInPictureAutomaticallyFromInline = true
        pip.requiresLinearPlayback = true
        controller = pip

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // PiP can still work in the simulator without an audio session.
        }

        startFrames()
    }

    /// Show the window now (must be called while the app is in the foreground).
    func present() {
        guard let controller, controller.isPictureInPicturePossible, !controller.isPictureInPictureActive else { return }
        controller.startPictureInPicture()
    }

    func dismiss() {
        controller?.stopPictureInPicture()
    }

    /// Update what the window says.
    func show(_ headline: String, detail: String, busy: Bool = false) {
        self.headline = headline
        self.detail = detail
        self.busy = busy
        renderFrame()
    }

    // MARK: Frames

    private func startFrames() {
        timer?.invalidate()
        renderFrame()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.renderFrame() }
        }
    }

    private func renderFrame() {
        if !busy, let status = statusProvider?() {
            headline = status.0
            detail = status.1
        }
        let size = CGSize(width: 480, height: 270)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            UIColor.systemBackground.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            // The mark: two rings.
            let ringColor = busy ? UIColor.systemBlue : UIColor.label
            cg.setStrokeColor(ringColor.cgColor)
            cg.setLineWidth(7)
            let r: CGFloat = 34
            let cy: CGFloat = 96
            let phase = busy ? CGFloat(frame % 8) : 0
            let gap: CGFloat = 26 - phase * 2
            cg.strokeEllipse(in: CGRect(x: 92 - gap / 2 - r, y: cy - r, width: 2 * r, height: 2 * r))
            cg.strokeEllipse(in: CGRect(x: 92 + gap / 2 - r, y: cy - r, width: 2 * r, height: 2 * r))

            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            let title: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph
            ]
            let body: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraph
            ]
            (headline as NSString).draw(in: CGRect(x: 160, y: 70, width: 300, height: 40), withAttributes: title)
            (detail as NSString).draw(in: CGRect(x: 160, y: 112, width: 300, height: 90), withAttributes: body)

            let hint = busy ? "Working…" : "Tap ⏸ to fuse"
            let hintAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            (hint as NSString).draw(at: CGPoint(x: 160, y: 226), withAttributes: hintAttrs)
        }
        enqueue(image)
    }

    private func enqueue(_ image: UIImage) {
        guard let cg = image.cgImage else { return }
        let width = cg.width, height = cg.height
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer) == kCVReturnSuccess,
              let buffer = pixelBuffer else { return }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) {
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])

        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &format) == noErr,
              let format else { return }

        frame += 1
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 2),
            presentationTimeStamp: CMTime(value: frame, timescale: 2),
            decodeTimeStamp: .invalid
        )
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescription: format, sampleTiming: &timing, sampleBufferOut: &sample) == noErr,
              let sample else { return }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true) as? [NSMutableDictionary], let first = attachments.first {
            first[kCMSampleAttachmentKey_DisplayImmediately] = true
        }
        if displayLayer.status == .failed { displayLayer.flush() }
        displayLayer.enqueue(sample)
    }
}

// MARK: - Delegates

extension FloatingOrb: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in self.isActive = true }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor in self.isActive = false }
    }

    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        Task { @MainActor in self.isActive = false }
    }

    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in
            self.onRestore?()
            completionHandler(true)
        }
    }
}

extension FloatingOrb: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {
        // The pause button is the only button in a PiP window we can own. Pause = fuse.
        if !playing {
            Task { @MainActor in self.onTrigger?() }
        }
    }

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
        false
    }

    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
