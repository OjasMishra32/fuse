import XCTest
@testable import Fuse

final class OpenLateTests: XCTestCase {

    private let json = """
    {"recipe":"late_night","title":"Still open near you","summary":"Four places you can make.",
     "artifact":{"type":"open_late","origin":"Palmer House","origin_latitude":41.8807,"origin_longitude":-87.6269,"now":"11:10 PM",
       "spots":[{"name":"Pizano's","category":"Pizza","closes":"1:00 AM","closes_at":"2026-09-27T01:00:00","travel":"2 min walk",
                 "leave_by":"12:38 AM","minutes_to_spare":108.0,"lat":41.8819,"lng":-87.6254},
                {"name":"Ramen-San","closes":"12:00 AM","travel":"13 min walk","minutes_to_spare":37}],
       "missed":[{"name":"The Gage","reason":"kitchen closes 11:30 PM, only 16 min after you arrive"}],
       "tip":"Portillo's drive-thru stays open later."}}
    """

    func testDecodesStillOpenPlan() throws {
        let result = try FuseEngine.decode(json)
        guard case .openLate(let plan) = result.artifact else { return XCTFail("expected open_late") }
        XCTAssertEqual(plan.origin, "Palmer House")
        XCTAssertEqual(plan.originLatitude, 41.8807)
        XCTAssertEqual(plan.spots.count, 2)
        XCTAssertEqual(plan.spots[0].minutesToSpare, 108, "whole minutes even when the model writes 108.0")
        XCTAssertEqual(plan.spots[0].latitude, 41.8819, "lat/lng aliases")
        XCTAssertNotNil(plan.spots[0].closesDate)
        XCTAssertNil(plan.spots[1].closesDate)
        XCTAssertEqual(plan.missed.first?.name, "The Gage")
        XCTAssertEqual(result.artifact.typeName, "open_late")
    }

    func testAliasesAndMissingFields() throws {
        let result = try FuseEngine.decode(#"{"artifact":{"type":"still_open","places":[{"name":"Jim's Original","closes":"Open 24 hours","minutes_to_spare":"lots"}]}}"#)
        guard case .openLate(let plan) = result.artifact else { return XCTFail("expected open_late") }
        XCTAssertEqual(plan.spots.first?.name, "Jim's Original")
        XCTAssertNil(plan.spots.first?.minutesToSpare)
        XCTAssertEqual(plan.origin, "")
        XCTAssertTrue(plan.missed.isEmpty)
    }

    func testRoundTripsAndReadsAsPlainText() throws {
        let result = try FuseEngine.decode(json)
        let back = try JSONDecoder().decode(FuseResult.self, from: JSONEncoder().encode(result))
        guard case .openLate(let plan) = back.artifact else { return XCTFail("expected open_late") }
        XCTAssertEqual(plan.spots.map(\.name), ["Pizano's", "Ramen-San"])
        let text = back.artifact.plainText
        XCTAssertTrue(text.contains("From Palmer House at 11:10 PM"))
        XCTAssertTrue(text.contains("1. Pizano's: Closes 1:00 AM · 2 min walk · leave by 12:38 AM"))
        XCTAssertTrue(text.contains("Too late tonight"))
    }

    func testCountdownOnlyWithinThreeHours() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(OpenLateArtifactView.countdown(to: now.addingTimeInterval(80 * 60), now: now), "in 1 hr 20 min")
        XCTAssertEqual(OpenLateArtifactView.countdown(to: now.addingTimeInterval(25 * 60), now: now), "in 25 min")
        XCTAssertEqual(OpenLateArtifactView.countdown(to: now.addingTimeInterval(120 * 60), now: now), "in 2 hr")
        XCTAssertNil(OpenLateArtifactView.countdown(to: now.addingTimeInterval(-60), now: now), "already closed")
        XCTAssertNil(OpenLateArtifactView.countdown(to: now.addingTimeInterval(9 * 3600), now: now), "a plan made for another time")
        XCTAssertNil(OpenLateArtifactView.countdown(to: nil, now: now))
    }

    @MainActor
    func testLateNightScenarioIsSeeded() throws {
        let scenario = try XCTUnwrap(DemoScenario.all.first { $0.id == "places-late-night" })
        XCTAssertNotNil(scenario.instruction)
    }
}
