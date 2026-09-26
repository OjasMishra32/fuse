import XCTest
@testable import Fuse

final class FuseEngineTests: XCTestCase {

    func testDecodesItineraryResult() throws {
        let json = """
        {"recipe":"travel_plan","title":"One day at Islands","summary":"Start at Hagrid's.",
         "artifact":{"type":"itinerary","destination":"Islands of Adventure",
           "days":[{"title":"Day 1","stops":[{"name":"Hagrid's","time":"9:05 AM","latitude":28.47,"longitude":-81.47}]}],
           "tips":["Buy Express"]},
         "follow_ups":["Add to calendar"]}
        """
        let result = try FuseEngine.decode(json)
        XCTAssertEqual(result.recipe, "travel_plan")
        XCTAssertEqual(result.followUps, ["Add to calendar"])
        guard case .itinerary(let it) = result.artifact else { return XCTFail("expected itinerary") }
        XCTAssertEqual(it.days.count, 1)
        XCTAssertEqual(it.allStops.first?.latitude, 28.47)
    }

    func testDecodesEventWithSnakeCaseAndLenientDates() throws {
        let json = """
        {"recipe":"event","title":"Demo","summary":"",
         "artifact":{"type":"event","title":"Swiftsonic keynote","start":"2026-11-20T09:30:00","all_day":false,"location":"Nashville"}}
        """
        let result = try FuseEngine.decode(json)
        guard case .event(let e) = result.artifact else { return XCTFail("expected event") }
        XCTAssertNotNil(e.startDate)
        XCTAssertEqual(e.location, "Nashville")
        XCTAssertNotNil(e.endDate, "end defaults to one hour after start")
    }

    func testUnknownArtifactFallsBackToMarkdown() throws {
        let json = """
        {"recipe":"x","title":"t","summary":"s","artifact":{"type":"haiku","text":"fold the phone"}}
        """
        let result = try FuseEngine.decode(json)
        guard case .markdown(let md) = result.artifact else { return XCTFail("expected markdown") }
        XCTAssertEqual(md, "fold the phone")
    }

    func testCodeFencesAreStripped() throws {
        let raw = "```json\n{\"recipe\":\"code\",\"title\":\"Patch\",\"summary\":\"\",\"artifact\":{\"type\":\"code\",\"language\":\"swift\",\"code\":\"print(1)\"}}\n```"
        let result = try FuseEngine.decode(raw)
        guard case .code(let c) = result.artifact else { return XCTFail("expected code") }
        XCTAssertEqual(c.language, "swift")
    }

    func testGarbageNeverThrows() throws {
        let result = try FuseEngine.decode("not json at all")
        guard case .markdown = result.artifact else { return XCTFail("expected markdown fallback") }
    }

    func testArtifactRoundTripsThroughCodable() throws {
        let original = FuseResult(
            recipe: "grade", title: "7/10", summary: "ok",
            artifact: .grade(GradeReport(score: "7/10", items: [.init(question: "q", yourAnswer: "a", correct: true)], weaknesses: ["x"], nextSteps: ["y"])),
            followUps: ["Quiz me"], inputs: [InputSummary(kind: .notes, title: "Test"), InputSummary(kind: .notes, title: "Answers")]
        )
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(FuseResult.self, from: data)
        XCTAssertEqual(back.title, "7/10")
        guard case .grade(let g) = back.artifact else { return XCTFail("expected grade") }
        XCTAssertEqual(g.items.count, 1)
        XCTAssertEqual(back.inputs.map(\.kind), [.notes, .notes])
    }

    func testIntentPreviewDecodesTopThree() {
        let raw = """
        {"suggestions":[{"title":"Plan the day","instruction":"Plan one day","artifact":"itinerary","symbol":"map"},
                        {"title":"Add to calendar","instruction":"Add it","artifact":"event"},
                        {"title":"Compare","instruction":"Compare","artifact":"table"},
                        {"title":"Fourth","instruction":"x","artifact":"markdown"}]}
        """
        let s = IntentPreviewer.decode(raw)
        XCTAssertEqual(s.count, 3)
        XCTAssertEqual(s.first?.resolvedSymbol, "map")
        XCTAssertEqual(s[1].resolvedSymbol, "calendar.badge.plus")
    }

    func testDateParsingVariants() {
        XCTAssertNotNil(FuseDates.parse("2026-10-03T18:00:00Z"))
        XCTAssertNotNil(FuseDates.parse("2026-10-03T18:00:00"))
        XCTAssertNotNil(FuseDates.parse("2026-10-03 18:00"))
        XCTAssertNotNil(FuseDates.parse("2026-10-03"))
        XCTAssertNil(FuseDates.parse("tomorrow-ish"))
    }

    func testConfigOverridesInfoPlist() {
        AppConfig.set("gpt-6-astra", for: .openAIModel)
        XCTAssertEqual(AppConfig.openAIModel, "gpt-6-astra")
        AppConfig.set("", for: .openAIModel)
        XCTAssertFalse(AppConfig.openAIModel.isEmpty, "falls back to plist or default")
        AppConfig.set("abc", for: .supabaseProjectRef)
        XCTAssertEqual(AppConfig.supabaseURL?.absoluteString, "https://abc.supabase.co")
        AppConfig.set("", for: .supabaseProjectRef)
    }

    @MainActor
    func testPromptsMentionEveryArtifactType() {
        let system = Prompts.system
        for type in ["itinerary", "event", "email", "quiz", "grade", "slides", "code", "diff", "table", "checklist", "image_edit", "markdown"] {
            XCTAssertTrue(system.contains("\"type\":\"\(type)\""), "catalogue is missing \(type)")
        }
    }

    @MainActor
    func testDemoScenariosAreWellFormed() {
        let all = DemoScenario.all
        XCTAssertGreaterThanOrEqual(all.count, 13)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "ids must be unique")
        for s in all { XCTAssertFalse(s.title.isEmpty); XCTAssertFalse(s.symbol.isEmpty) }
    }
}
