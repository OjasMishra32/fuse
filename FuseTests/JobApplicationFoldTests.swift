import XCTest
@testable import Fuse

final class JobApplicationFoldTests: XCTestCase {
    func testClosedLaunchAndDuplicateEventsCannotApply() {
        var gate = JobApplicationFoldGate()
        XCTAssertFalse(gate.observe(closed: true, open: false, eligible: true))
        XCTAssertFalse(gate.observe(closed: false, open: true, eligible: true))
        XCTAssertTrue(gate.observe(closed: true, open: false, eligible: true))
        XCTAssertFalse(gate.observe(closed: true, open: false, eligible: true))
    }
    func testUnpreparedCloseIsConsumedAndNeedsReopen() {
        var gate = JobApplicationFoldGate()
        _ = gate.observe(closed: false, open: true, eligible: false)
        XCTAssertFalse(gate.observe(closed: true, open: false, eligible: false))
        XCTAssertFalse(gate.observe(closed: true, open: false, eligible: true))
        _ = gate.observe(closed: false, open: true, eligible: true)
        XCTAssertTrue(gate.observe(closed: true, open: false, eligible: true))
    }
    @MainActor func testJobScenarioPreservesTeamRecipesAndNeverUsesGenericPreview() {
        XCTAssertNotNil(DemoScenario.named("theme-park"))
        XCTAssertNotNil(DemoScenario.named("cover-email"))
        let model = AppModel()
        model.apply(DemoScenario.named("job-application")!)
        XCTAssertTrue(model.jobDemoActive)
        XCTAssertEqual(model.left.kind, .web)
        XCTAssertEqual(model.right.kind, .notes)
        model.schedulePreview()
        XCTAssertFalse(model.isPreviewing)
        XCTAssertTrue(model.suggestions.isEmpty)
        XCTAssertFalse(model.jobCanCombine, "A background workspace cannot submit")
    }

    @MainActor func testCompleteSamplePairActivatesInBothOrders() {
        for reversed in [false, true] {
            let model = AppModel()
            let jobPane = reversed ? model.right : model.left
            let resumePane = reversed ? model.left : model.right
            jobPane.apply(.url(JobApplicationDemo.jobURL), as: .web)
            resumePane.apply(.text(JobApplicationDemo.resume), as: .notes)
            let session = model.jobApplication
            XCTAssertTrue(model.jobApplicationPair?.job === jobPane.model)
            XCTAssertTrue(model.jobApplicationPair?.resume === resumePane.model)
            model.schedulePreview()
            XCTAssertTrue(model.jobDemoActive)
            XCTAssertFalse(model.isPreviewing)
            XCTAssertTrue(model.suggestions.isEmpty)
            XCTAssertTrue(model.jobApplication === session, "Recognition preserves the existing application session")
            XCTAssertFalse(model.jobFoldGate.observe(closed: true, open: false, eligible: true),
                           "Recognition without an observed open must not arm a close")
            (jobPane.model as? WebSurfaceModel)?.stop()
        }
    }

    @MainActor func testPartialResumeAndUnrelatedBrowserDoNotActivateApplication() {
        let model = AppModel()
        model.left.apply(.url(JobApplicationDemo.jobURL), as: .web)
        model.right.apply(.text("ALEX MORGAN\nContact details only"), as: .notes)
        XCTAssertNil(model.jobApplicationPair)
        model.activateJobApplicationIfRecognized()
        XCTAssertFalse(model.jobDemoActive)

        model.right.apply(.text(JobApplicationDemo.resume), as: .notes)
        model.left.apply(.url(URL(string: "https://example.com/jobs")!), as: .web)
        XCTAssertNil(model.jobApplicationPair)
        model.activateJobApplicationIfRecognized()
        XCTAssertFalse(model.jobDemoActive)
        (model.left.model as? WebSurfaceModel)?.stop()
    }

    @MainActor func testCompletingResumeWithSameHeadlineChangesRecognitionKey() {
        let model = AppModel()
        model.left.apply(.url(JobApplicationDemo.jobURL), as: .web)
        model.right.apply(.text("ALEX MORGAN\nPartial résumé"), as: .notes)
        let partialKey = model.contentKey
        model.right.apply(.text("\n  " + JobApplicationDemo.resume + "\n"), as: .notes)
        XCTAssertNotEqual(partialKey, model.contentKey)
        XCTAssertNotNil(model.jobApplicationPair, "Whitespace changes do not make a different source")
        (model.left.model as? WebSurfaceModel)?.stop()
    }
}
