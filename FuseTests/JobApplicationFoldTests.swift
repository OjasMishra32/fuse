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
            XCTAssertFalse(model.jobShowingResult, "Recognizing a pair must not replace the shared two-app stage")
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
    @MainActor func testLeavingJobFlowClearsItsInstructionAndPreservesSession() {
        let model = AppModel()
        model.apply(DemoScenario.named("job-application")!)
        let session = model.jobApplication
        XCTAssertFalse(model.instruction.isEmpty)
        model.leaveJobApplication()
        XCTAssertFalse(model.jobDemoActive)
        XCTAssertTrue(model.instruction.isEmpty)
        XCTAssertTrue(model.left.isHome && model.right.isHome)
        XCTAssertTrue(model.jobApplication === session)
    }

    @MainActor func testChangingJobPairReturnsToGeneralFusion() {
        let model = AppModel()
        model.apply(DemoScenario.named("job-application")!)
        model.left.open(.photo)
        model.right.open(.photo)
        model.activateJobApplicationIfRecognized()
        XCTAssertFalse(model.jobDemoActive)
        XCTAssertNil(model.jobApplicationPair)
        XCTAssertTrue(model.instruction.isEmpty, "Photos must not inherit the job instruction")
        XCTAssertFalse(model.jobCanCombine)
    }

    @MainActor func testAnotherInstructionOnSamePairUsesGeneralEngine() {
        let model = AppModel()
        model.apply(DemoScenario.named("job-application")!)
        model.instruction = "Create interview practice questions for this role"
        model.activateJobApplicationIfRecognized()
        XCTAssertFalse(model.jobDemoActive)
        XCTAssertEqual(model.instruction, "Create interview practice questions for this role")
    }

    @MainActor func testOtherTeamRecipesRemainOutsideJobRoute() {
        for id in ["two-photos", "theme-park", "cover-email"] {
            let model = AppModel()
            model.apply(DemoScenario.named("job-application")!)
            let other = DemoScenario.named(id)!
            model.apply(other)
            model.activateJobApplicationIfRecognized()
            XCTAssertFalse(model.jobDemoActive, id)
            XCTAssertEqual(model.instruction, other.instruction ?? "", id)
            XCTAssertNil(model.jobApplicationPair, id)
            (model.left.model as? WebSurfaceModel)?.stop()
            (model.right.model as? WebSurfaceModel)?.stop()
        }
    }

    @MainActor func testResetExitsJobPresentation() {
        let model = AppModel()
        model.apply(DemoScenario.named("job-application")!)
        model.resetPanes()
        XCTAssertFalse(model.jobDemoActive)
        XCTAssertTrue(model.instruction.isEmpty)
    }

    @MainActor func testHomeLinkClearsJobInstructionBeforeManualPairing() {
        let model = AppModel()
        model.apply(DemoScenario.named("job-application")!)
        model.handle(url: URL(string: "fuse://home")!)
        XCTAssertFalse(model.jobDemoActive)
        XCTAssertTrue(model.instruction.isEmpty)
        model.left.apply(.text("A contract"), as: .notes)
        model.right.apply(.text("A company policy"), as: .notes)
        model.activateJobApplicationIfRecognized()
        XCTAssertFalse(model.jobDemoActive)
    }

    @MainActor func testJobRecipeComposesOnTheSharedStageUntilFusion() {
        let model = AppModel()
        model.apply(DemoScenario.named("job-application")!)
        XCTAssertTrue(model.jobDemoActive)
        XCTAssertFalse(model.jobShowingResult)
        model.jobShowingResult = true
        model.apply(DemoScenario.named("two-photos")!)
        XCTAssertFalse(model.jobShowingResult)
        XCTAssertFalse(model.jobDemoActive)
    }

}
