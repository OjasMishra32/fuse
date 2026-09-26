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
}
