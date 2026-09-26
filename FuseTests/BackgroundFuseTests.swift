import XCTest
import UIKit
@testable import Fuse

/// Pure unit tests for the background fuse boundaries: cropping, jobs, artifact restriction and
/// the service's exactly-once completion with a fake engine. No network, no Photos.
final class BackgroundFuseTests: XCTestCase {

    // MARK: Fixtures

    /// A `width`×`height` pixel image whose left half is red and right half is blue.
    private func twoColorImage(width: Int, height: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: width, height: height)
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(width) / 2, height: CGFloat(height)))
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: CGFloat(width) / 2, y: 0, width: CGFloat(width) / 2, height: CGFloat(height)))
        }
    }

    private struct RGB { var r: CGFloat; var g: CGFloat; var b: CGFloat }

    private func averageColor(_ image: UIImage) -> RGB {
        guard let cg = image.cgImage else { return RGB(r: -1, g: -1, b: -1) }
        var pixel = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return RGB(r: -1, g: -1, b: -1)
        }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return RGB(r: CGFloat(pixel[0]) / 255, g: CGFloat(pixel[1]) / 255, b: CGFloat(pixel[2]) / 255)
    }

    private func isRed(_ c: RGB) -> Bool { c.r > 0.85 && c.g < 0.15 && c.b < 0.15 }
    private func isBlue(_ c: RGB) -> Bool { c.b > 0.85 && c.r < 0.15 && c.g < 0.15 }

    private func pixelSize(_ image: UIImage) -> (Int, Int) {
        guard let cg = image.cgImage else { return (0, 0) }
        return (cg.width, cg.height)
    }

    private func sampleResult(artifact: FuseArtifact, summary: String = "Two apps, one answer.") -> FuseResult {
        FuseResult(recipe: "test", title: "Fused", summary: summary, artifact: artifact, followUps: ["Again"])
    }

    private func temporaryStore() throws -> FuseJobStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fuse-jobs-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return FuseJobStore(directory: dir)
    }

    // MARK: ScreenshotInput

    func testLeftRightCropSeparatesRedAndBlue() throws {
        let image = twoColorImage(width: 200, height: 100)
        let crops = try ScreenshotInput.crop(image, layout: .auto)
        XCTAssertEqual(crops.layout, .leftRight)
        XCTAssertEqual(pixelSize(crops.first).0, 100)
        XCTAssertEqual(pixelSize(crops.first).1, 100)
        XCTAssertEqual(pixelSize(crops.second).0, 100)
        XCTAssertTrue(isRed(averageColor(crops.first)), "left half should be red")
        XCTAssertTrue(isBlue(averageColor(crops.second)), "right half should be blue")
    }

    func testOddEdgePixelGoesToSecondHalf() throws {
        let image = twoColorImage(width: 201, height: 100)
        let crops = try ScreenshotInput.crop(image, layout: .leftRight)
        XCTAssertEqual(pixelSize(crops.first).0, 100)
        XCTAssertEqual(pixelSize(crops.second).0, 101)
        XCTAssertEqual(pixelSize(crops.first).0 + pixelSize(crops.second).0, 201, "no pixel column is lost")
    }

    func testAutoLayoutFollowsAspectRatio() {
        XCTAssertEqual(FuseLayout.auto.resolved(width: 200, height: 100), .leftRight)
        XCTAssertEqual(FuseLayout.auto.resolved(width: 100, height: 200), .topBottom)
        XCTAssertEqual(FuseLayout.auto.resolved(width: 100, height: 100), .leftRight)
        XCTAssertEqual(FuseLayout.topBottom.resolved(width: 200, height: 100), .topBottom, "explicit layout is never overridden")
    }

    func testExplicitTopBottomOnWideImage() throws {
        let image = twoColorImage(width: 200, height: 100)
        let crops = try ScreenshotInput.crop(image, layout: .topBottom)
        XCTAssertEqual(crops.layout, .topBottom)
        XCTAssertEqual(pixelSize(crops.first).1, 50)
        XCTAssertEqual(pixelSize(crops.second).1, 50)
        XCTAssertEqual(pixelSize(crops.first).0, 200)
    }

    func testRotatedCaptureIsNormalizedBeforeCropping() throws {
        // Same pixels tagged as rotated: displayed size becomes 100×200, so auto → topBottom,
        // and each half is still a solid single color.
        guard let cg = twoColorImage(width: 200, height: 100).cgImage else { return XCTFail("no cgImage") }
        let rotated = UIImage(cgImage: cg, scale: 1, orientation: .left)
        let crops = try ScreenshotInput.crop(rotated, layout: .auto)
        XCTAssertEqual(crops.layout, .topBottom)
        XCTAssertEqual(crops.sourceWidth, 100)
        XCTAssertEqual(crops.sourceHeight, 200)
        let a = averageColor(crops.first), b = averageColor(crops.second)
        XCTAssertTrue((isRed(a) && isBlue(b)) || (isBlue(a) && isRed(b)), "each half stays a single color after normalization")
    }

    func testRejectsOneByOneImage() {
        let tiny = twoColorImage(width: 1, height: 1)
        XCTAssertThrowsError(try ScreenshotInput.crop(tiny, layout: .auto)) { error in
            guard case ScreenshotInput.InputError.tooSmall = error else { return XCTFail("expected tooSmall, got \(error)") }
        }
    }

    func testRejectsUndecodableData() {
        XCTAssertThrowsError(try ScreenshotInput.decode(Data()))
        XCTAssertThrowsError(try ScreenshotInput.decode(Data([0x00, 0x01, 0x02])))
    }

    func testSnapshotsCarryScreenshotProvenance() throws {
        let image = twoColorImage(width: 200, height: 100)
        let (left, right, _) = try ScreenshotInput.snapshots(from: image, layout: .auto)
        XCTAssertEqual(left.kind, .photo)
        XCTAssertEqual(left.title, "Left app")
        XCTAssertEqual(right.title, "Right app")
        XCTAssertEqual(left.metadata["source"], "screenshot")
        XCTAssertEqual(right.metadata["layout"], "leftRight")
        XCTAssertNotNil(left.image)
        XCTAssertNotNil(right.image)
    }

    // MARK: FuseJobStore

    func testJobStoreRoundTrip() async throws {
        let store = try temporaryStore()
        let job = try await store.create(instruction: "plan dinner", layout: .leftRight)
        XCTAssertEqual(job.state, .pending)

        let result = sampleResult(artifact: .checklist(Checklist(title: "Dinner", items: [.init(text: "Book table")])))
        let first = try await store.complete(id: job.id, result: result)
        XCTAssertTrue(first)

        let loaded = await store.load(id: job.id)
        XCTAssertEqual(loaded?.state, .done)
        XCTAssertEqual(loaded?.instruction, "plan dinner")
        XCTAssertEqual(loaded?.layout, .leftRight)
        XCTAssertEqual(loaded?.result?.id, result.id)
        XCTAssertEqual(loaded?.result?.title, "Fused")
        guard case .checklist(let list)? = loaded?.result?.artifact else { return XCTFail("expected checklist") }
        XCTAssertEqual(list.items.first?.text, "Book table")

        let latest = await store.latest()
        XCTAssertEqual(latest?.id, job.id)
    }

    func testJobCompletesExactlyOnce() async throws {
        let store = try temporaryStore()
        let job = try await store.create(instruction: nil, layout: .auto)
        let result = sampleResult(artifact: .markdown("hi"))
        let first = try await store.complete(id: job.id, result: result)
        XCTAssertTrue(first)
        let second = try await store.complete(id: job.id, result: result)
        XCTAssertFalse(second, "second completion is ignored")
        let lateFail = try await store.fail(id: job.id, error: "late")
        XCTAssertFalse(lateFail, "a finished job cannot be failed afterwards")
        let loaded = await store.load(id: job.id)
        XCTAssertEqual(loaded?.state, .done)
    }

    func testCleanupRemovesExpiredJobs() async throws {
        let store = try temporaryStore()
        let old = FuseJob(createdAt: Date().addingTimeInterval(-48 * 3600), instruction: nil, layout: .auto)
        try await store.save(old)
        let fresh = try await store.create(instruction: nil, layout: .auto)
        let removed = await store.cleanup()
        XCTAssertEqual(removed, 1)
        let oldLoaded = await store.load(id: old.id)
        XCTAssertNil(oldLoaded)
        let freshLoaded = await store.load(id: fresh.id)
        XCTAssertNotNil(freshLoaded)
    }

    // MARK: Artifact restriction

    func testImageArtifactBecomesMarkdownOfSummary() {
        let image = ImageArtifact(prompt: "merge both photos", caption: "A poster")
        let restricted = BackgroundFuseService.restrictArtifact(sampleResult(artifact: .image(image), summary: "Here is the gist."))
        guard case .markdown(let md) = restricted.artifact else { return XCTFail("expected markdown") }
        XCTAssertEqual(md, "Here is the gist.")
        XCTAssertEqual(restricted.title, "Fused")
    }

    func testImageArtifactWithEmptySummaryUsesCaption() {
        let image = ImageArtifact(prompt: "merge both photos", caption: "A poster")
        let restricted = BackgroundFuseService.restrictArtifact(sampleResult(artifact: .image(image), summary: "  "))
        guard case .markdown(let md) = restricted.artifact else { return XCTFail("expected markdown") }
        XCTAssertEqual(md, "A poster")
    }

    func testTextArtifactsPassThroughUnchanged() {
        let original = sampleResult(artifact: .email(EmailDraft(to: ["a@b.c"], subject: "Hi", body: "Body")))
        XCTAssertEqual(BackgroundFuseService.restrictArtifact(original), original)
    }

    // MARK: BackgroundFuseService with a fake engine

    func testServiceRunsEngineOnceAndRecordsSuccessOnce() async throws {
        let store = try temporaryStore()
        let calls = Counter()
        let successes = Counter()
        let service = BackgroundFuseService(
            store: store,
            engine: { left, right, instruction in
                await calls.increment()
                XCTAssertEqual(instruction, "make a checklist")
                XCTAssertEqual(left.title, "Left app")
                XCTAssertEqual(right.title, "Right app")
                return FuseResult(recipe: "r", title: "T", summary: "S", artifact: .image(ImageArtifact(prompt: "p")))
            },
            enforcesConfiguration: false,
            onSuccess: { _ in await successes.increment() }
        )
        let result = try await service.run(image: twoColorImage(width: 200, height: 100), instruction: "  make a checklist ", layout: .auto)
        guard case .markdown(let md) = result.artifact else { return XCTFail("image artifact must be restricted") }
        XCTAssertEqual(md, "S")
        XCTAssertEqual(result.instruction, "make a checklist")
        XCTAssertEqual(result.inputs.map(\.title), ["Left app", "Right app"])
        let engineCalls = await calls.value
        let successCalls = await successes.value
        XCTAssertEqual(engineCalls, 1)
        XCTAssertEqual(successCalls, 1)

        let job = await store.latest()
        XCTAssertEqual(job?.state, .done)
        XCTAssertEqual(job?.result?.id, result.id)
    }

    func testServiceFailsJobWhenEngineThrowsAndNeverRecordsSuccess() async throws {
        let store = try temporaryStore()
        let successes = Counter()
        struct Boom: Error {}
        let service = BackgroundFuseService(
            store: store,
            engine: { _, _, _ in throw Boom() },
            enforcesConfiguration: false,
            onSuccess: { _ in await successes.increment() }
        )
        do {
            _ = try await service.run(image: twoColorImage(width: 200, height: 100), instruction: nil, layout: .leftRight)
            XCTFail("expected the engine error to propagate")
        } catch {
            XCTAssertTrue(error is Boom)
        }
        let successCalls = await successes.value
        XCTAssertEqual(successCalls, 0)
        let job = await store.latest()
        XCTAssertEqual(job?.state, .failed)
        XCTAssertNil(job?.result)
    }

    func testServiceRejectsTinyImageBeforeCreatingAJob() async throws {
        let store = try temporaryStore()
        let service = BackgroundFuseService(store: store, engine: { _, _, _ in XCTFail("engine must not run"); throw CancellationError() }, enforcesConfiguration: false, onSuccess: { _ in })
        do {
            _ = try await service.run(image: twoColorImage(width: 1, height: 1), instruction: nil, layout: .auto)
            XCTFail("expected a validation error")
        } catch {
            guard case ScreenshotInput.InputError.tooSmall = error else { return XCTFail("expected tooSmall, got \(error)") }
        }
        let jobs = await store.all()
        XCTAssertTrue(jobs.isEmpty)
    }

    // MARK: Snippet rows

    func testSnippetRowsAreCompact() {
        let list = Checklist(title: "Trip", items: (1...10).map { Checklist.Item(text: "Item \($0)") })
        XCTAssertEqual(FuseSnippetView.rows(for: .checklist(list)).count, 4)
        let md = (1...12).map { "line \($0)" }.joined(separator: "\n")
        XCTAssertEqual(FuseSnippetView.rows(for: .markdown(md)).count, 5)
        let mail = EmailDraft(to: ["x@y.z"], subject: "Hello", body: "\nFirst line\nSecond")
        XCTAssertEqual(FuseSnippetView.rows(for: .email(mail)), ["To: x@y.z", "Subject: Hello", "First line"])
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}
