import XCTest
@testable import Fuse

final class JobApplicationFoldTests: XCTestCase {
    // Explicit opt-in only. Read an existing local configuration without logging credentials.
    @MainActor func testLiveSharedRouterWithDifferentInputs() async throws {
        guard let path = ProcessInfo.processInfo.environment["FUSE_LIVE_CONFIG_PLIST"] else {
            throw XCTSkip("Live network verification is opt-in")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let config = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let key = config?["fuse.config.openAIKey"] as? String ?? ""
        guard !key.isEmpty else { throw XCTSkip("No configured API key") }
        let client = OpenAIClient(apiKey: key, model: config?["fuse.config.openAIModel"] as? String ?? AppConfig.openAIModel)
        let engine = FuseEngine(client: client)
        for (name, company, reversed) in [("Sam Rivera", "Northstar", false), ("Jordan Lee", "Harbor Studio", true)] {
            let (resume, job) = inputs(name, company: company)
            let result = try await engine.fuse(left: reversed ? job : resume, right: reversed ? resume : job,
                                              instruction: nil, progress: { _ in })
            guard case .application(let application) = result.artifact else { return XCTFail("Expected application") }
            XCTAssertEqual(application.candidate, name)
            XCTAssertEqual(application.company, company)
            XCTAssertFalse(application.tailoredResume?.isEmpty ?? true)
            XCTAssertFalse(application.coverLetter.contains("Alex Morgan"))
        }
        let (resume, _) = inputs()
        let map = SurfaceSnapshot(kind: .maps, title: "Portland", text: "Portland, Oregon. Selected location: downtown. Coordinates 45.52, -122.67.")
        let other = try await engine.fuse(left: resume, right: map, instruction: nil, progress: { _ in })
        if case .application = other.artifact { XCTFail("An unrelated map must not create a job application") }
    }

    private func inputs(_ name: String = "Sam Rivera", company: String = "Northstar") -> (SurfaceSnapshot, SurfaceSnapshot) {
        let resume = "\(name)\nsam@example.com\nSoftware engineer at Atlas, 2022–2025.\nReduced build time by 25% using Swift and automated testing.\nSkills: Swift, testing, collaboration."
        let job = "\(company) is hiring an iOS Engineer. Build accessible Swift applications and improve testing reliability. Collaborate with designers and review code."
        return (SurfaceSnapshot(kind: .document, title: "CV.txt", text: resume),
                SurfaceSnapshot(kind: .web, title: "Careers", text: job))
    }

    private func draft(_ name: String = "Sam Rivera", company: String = "Northstar", side: String = "left") -> ApplicationDraft {
        ApplicationDraft(company: company, role: "iOS Engineer", candidate: name, email: "sam@example.com",
            resumeSide: side,
            edits: [.init(original: "Reduced build time by 25% using Swift and automated testing.",
                          revised: "Improved Swift build efficiency by 25% through automated testing.",
                          reason: "Highlights the testing skills required by the role.")],
            coverLetter: "I am interested in the iOS Engineer role. My Swift development and automated testing experience can contribute to your team.",
            missingInformation: ["Work authorization was not supplied."])
    }

    func testDifferentCandidatesAndEmployersInBothOrders() throws {
        for (name, company) in [("Sam Rivera", "Northstar"), ("Jordan Lee", "Harbor Studio")] {
            let (resume, job) = inputs(name, company: company)
            for reversed in [false, true] {
                let result = try draft(name, company: company, side: reversed ? "right" : "left")
                    .grounded(left: reversed ? job : resume, right: reversed ? resume : job)
                XCTAssertEqual(result.candidate, name)
                XCTAssertEqual(result.company, company)
                XCTAssertTrue(result.tailoredResume!.contains("Improved Swift build efficiency by 25%"))
                XCTAssertTrue(result.tailoredResume!.contains("Atlas, 2022–2025"))
                XCTAssertEqual(result.sourceResume, resume.text)
                let artifact = FuseArtifact.application(result)
                let decoded = try JSONDecoder().decode(FuseArtifact.self, from: JSONEncoder().encode(artifact))
                XCTAssertEqual(artifact, decoded)
                XCTAssertTrue(artifact.compactText.contains(name))
            }
        }
    }

    func testRejectsInventedContactMetricsAndUnrelatedJob() throws {
        let (resume, job) = inputs()
        var invalid = draft()
        invalid.email = "invented@example.com"
        XCTAssertThrowsError(try invalid.grounded(left: resume, right: job))
        invalid = draft()
        invalid.edits[0].revised = "Improved build time by 90%."
        XCTAssertThrowsError(try invalid.grounded(left: resume, right: job))
        invalid = draft()
        invalid.edits[0].original = "Made up achievement"
        XCTAssertThrowsError(try invalid.grounded(left: resume, right: job))
        XCTAssertThrowsError(try draft().grounded(left: resume,
            right: SurfaceSnapshot(kind: .maps, title: "Map", text: "A nearby park")))
        XCTAssertThrowsError(try draft().grounded(left: .empty(.document), right: job))
    }

    func testAIProvidedSourceCannotReplaceTheResume() throws {
        let (resume, job) = inputs()
        var value = draft()
        value.sourceResume = "Fabricated"
        value.tailoredResume = "Fabricated"
        let result = try value.grounded(left: resume, right: job)
        XCTAssertEqual(result.sourceResume, resume.text)
        XCTAssertFalse(result.tailoredResume!.contains("Fabricated"))
    }

    @MainActor func testSampleAndOtherRecipesAllUseSharedRoute() {
        let model = AppModel()
        for id in ["job-application", "two-photos", "theme-park", "cover-email"] {
            model.apply(DemoScenario.named(id)!)
            XCTAssertFalse(model.jobDemoActive)
            XCTAssertFalse(model.jobShowingResult)
        }
        XCTAssertNil(DemoScenario.named("job-application")!.instruction)
        (model.left.model as? WebSurfaceModel)?.stop()
    }

    @MainActor func testChangedResumeInvalidatesCachedResultEvenWithSameTitle() {
        let model = AppModel()
        for kind: SurfaceKind in [.notes, .document] {
            model.left.apply(.text("Same title\nFirst experience"), as: kind)
            let old = model.contentKey
            model.left.apply(.text("Same title\nDifferent experience"), as: kind)
            XCTAssertNotEqual(old, model.contentKey)
        }
    }
}
