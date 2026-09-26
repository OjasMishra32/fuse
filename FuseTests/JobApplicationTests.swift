import XCTest
@testable import Fuse

@MainActor
final class JobApplicationTests: XCTestCase {
    private func storage() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("job-application-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("current.json")
    }

    private func network() -> URLSession {
        addTeardownBlock { JobApplicationTestProtocol.handler = nil }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [JobApplicationTestProtocol.self]
        return URLSession(configuration: config)
    }

    private func draft() -> JobApplicationDraft {
        JobApplicationDraft(edits: [
            .init(original: JobApplicationDemo.checkoutBullet,
                  revised: "Partnered with design and engineering to improve checkout conversion by 12% using funnel analysis and experiments.",
                  reason: "Lead with measurable checkout conversion evidence."),
            .init(original: JobApplicationDemo.researchBullet,
                  revised: "Shaped roadmap priorities by interviewing 20 merchants about onboarding friction.",
                  reason: "Connect merchant discovery to roadmap decisions.")
        ], coverLetter: "Dear Bright Labs team, I am interested in the Product Manager role. At Cedar Commerce I worked with design and engineering on checkout conversion and interviewed merchants about onboarding friction. I would welcome the opportunity to bring that evidence-led approach to your team. Alex Morgan", gaps: ["International expansion experience is not documented.", "Pricing experience is not documented."])
    }

    nonisolated private func receiptData(for body: Data, destination: String = JobApplicationDemo.destination) throws -> Data {
        let request = try JSONDecoder().decode(JobApplicationSubmission.self, from: body)
        return try JSONEncoder().encode(JobApplicationReceipt(
            applicationID: request.applicationID, receiptID: "demo-receipt-123",
            jobID: request.jobID, candidateName: request.candidateName,
            receivedAt: "2026-09-26T17:00:00.000Z", status: "received", destination: destination))
    }

    private func finish(_ session: JobApplicationSession) async throws {
        let deadline = Date().addingTimeInterval(4)
        while session.isBusy && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(session.isBusy, "The test request should finish without real network access.")
    }

    func testSourceValidationAcceptsBrowserWhitespaceAndRejectsRealCandidate() throws {
        XCTAssertNoThrow(try JobApplicationDemo.validateSources(
            job: JobApplicationDemo.normalize(JobApplicationDemo.jobText), resume: JobApplicationDemo.resume))
        XCTAssertThrowsError(try JobApplicationDemo.validateSources(job: JobApplicationDemo.jobText,
            resume: JobApplicationDemo.resume.replacingOccurrences(of: "ALEX MORGAN", with: "REAL PERSON")))
        XCTAssertThrowsError(try JobApplicationDemo.validateSources(job: "Real company job", resume: JobApplicationDemo.resume))
    }

    func testDraftPreservesIdentityDatesAndMetrics() throws {
        let result = try draft().validatedResume(from: JobApplicationDemo.resume)
        XCTAssertTrue(result.contains("Cedar Commerce · 2022–2026"))
        XCTAssertTrue(result.contains(JobApplicationDemo.email))
        XCTAssertTrue(result.contains("12%"))
        XCTAssertTrue(result.contains("20 merchants"))
        XCTAssertTrue(result.contains("FICTIONAL CANDIDATE"))
        XCTAssertNotEqual(result, JobApplicationDemo.resume)
    }

    func testDraftRejectsInventedMetricsAndUnsupportedEdit() {
        let original = draft()
        let inflated = JobApplicationDraft(edits: [.init(original: JobApplicationDemo.checkoutBullet,
            revised: "Improved checkout conversion by 50%.", reason: "Inflate metric")],
            coverLetter: original.coverLetter, gaps: [])
        XCTAssertThrowsError(try inflated.validatedResume(from: JobApplicationDemo.resume))
        let changedIdentity = JobApplicationDraft(edits: [.init(original: "ALEX MORGAN", revised: "Someone else", reason: "Replace identity")],
            coverLetter: original.coverLetter, gaps: [])
        XCTAssertThrowsError(try changedIdentity.validatedResume(from: JobApplicationDemo.resume))
        let inventedLetter = JobApplicationDraft(edits: original.edits,
            coverLetter: original.coverLetter + " I managed 900 engineers.", gaps: [])
        XCTAssertThrowsError(try inventedLetter.validatedResume(from: JobApplicationDemo.resume))
    }

    func testMissingOrRealInputsNeverCallAIOrSubmit() async throws {
        var aiCalls = 0
        let prepared = draft()
        JobApplicationTestProtocol.handler = { _, _ in XCTFail("No request should be made"); throw URLError(.badURL) }
        let session = JobApplicationSession(storageURL: try storage(), session: network(), tailor: { _, _ in
            aiCalls += 1; return prepared
        })
        session.start(jobText: "", resumeText: "")
        XCTAssertEqual(aiCalls, 0)
        XCTAssertNotNil(session.error)
        XCTAssertNil(session.applicationID)
    }

    func testDuplicateFoldAndReopenProduceOneConfirmedApplication() async throws {
        let prepared = draft()
        let file = try storage()
        var aiCalls = 0
        let requests = JobApplicationRequestLog()
        JobApplicationTestProtocol.handler = { [self] request, body in
            requests.append(body)
            XCTAssertEqual(request.url, JobApplicationDemo.submissionURL)
            XCTAssertEqual(request.httpMethod, "POST")
            let submission = try JSONDecoder().decode(JobApplicationSubmission.self, from: body)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), submission.applicationID)
            XCTAssertEqual(submission.email, "alex.morgan@example.com")
            return (201, try receiptData(for: body))
        }
        let session = JobApplicationSession(storageURL: file, session: network(), tailor: { _, _ in
            aiCalls += 1
            try await Task.sleep(nanoseconds: 50_000_000)
            return prepared
        })
        session.start(jobText: JobApplicationDemo.jobText, resumeText: JobApplicationDemo.resume)
        session.start(jobText: JobApplicationDemo.jobText, resumeText: JobApplicationDemo.resume)
        session.retry()
        XCTAssertTrue(session.isBusy)
        try await finish(session)
        XCTAssertEqual(aiCalls, 1)
        XCTAssertEqual(requests.bodies.count, 1)
        XCTAssertTrue(session.hasSubmitted)
        XCTAssertEqual(session.receipt?.destination, JobApplicationDemo.destination)
        session.start(jobText: JobApplicationDemo.jobText, resumeText: JobApplicationDemo.resume)
        XCTAssertEqual(requests.bodies.count, 1)
        let reopened = JobApplicationSession(storageURL: file, session: network(), tailor: { _, _ in
            XCTFail("A received application must not rerun AI"); return prepared
        })
        XCTAssertTrue(reopened.hasSubmitted)
        XCTAssertEqual(reopened.tailoredResume, session.tailoredResume)
        XCTAssertEqual(reopened.receipt, session.receipt)
        XCTAssertEqual(requests.bodies.count, 1)
    }

    func testUncertainDeliveryRelaunchAndRetryReuseExactIDAndPayload() async throws {
        let prepared = draft()
        let file = try storage()
        let requests = JobApplicationRequestLog()
        var aiCalls = 0
        JobApplicationTestProtocol.handler = { _, body in
            requests.append(body)
            throw URLError(.timedOut)
        }
        let first = JobApplicationSession(storageURL: file, session: network(), tailor: { _, _ in aiCalls += 1; return prepared })
        first.start(jobText: JobApplicationDemo.jobText, resumeText: JobApplicationDemo.resume)
        try await finish(first)
        XCTAssertFalse(first.hasSubmitted)
        XCTAssertNotNil(first.error)
        let id = first.applicationID
        first.reset()
        XCTAssertEqual(first.applicationID, id, "An uncertain send retains its deduplication identifier.")
        JobApplicationTestProtocol.handler = { [self] _, body in
            requests.append(body)
            return (200, try receiptData(for: body))
        }
        let restored = JobApplicationSession(storageURL: file, session: network(), tailor: { _, _ in
            aiCalls += 1; return prepared
        })
        XCTAssertFalse(restored.isBusy, "Restoring does not silently send a pending application.")
        restored.retry()
        try await finish(restored)
        XCTAssertTrue(restored.hasSubmitted)
        XCTAssertEqual(restored.applicationID, id)
        XCTAssertEqual(aiCalls, 1)
        XCTAssertEqual(requests.bodies.count, 2)
        XCTAssertEqual(requests.bodies.first, requests.bodies.last)
    }

    func testReceiptMustMatchExpectedDestination() async throws {
        let prepared = draft()
        JobApplicationTestProtocol.handler = { [self] _, body in (201, try receiptData(for: body, destination: "A real employer")) }
        let session = JobApplicationSession(storageURL: try storage(), session: network(), tailor: { _, _ in prepared })
        session.start(jobText: JobApplicationDemo.jobText, resumeText: JobApplicationDemo.resume)
        try await finish(session)
        XCTAssertFalse(session.hasSubmitted)
        XCTAssertNil(session.receipt)
        XCTAssertTrue(session.error?.contains("valid receipt") == true)
    }

    func testInvalidAIOutputNeverSubmits() async throws {
        let wrong = JobApplicationDraft(edits: [], coverLetter: "Fake", gaps: [])
        JobApplicationTestProtocol.handler = { _, _ in XCTFail("Invalid draft must never be sent"); throw URLError(.badURL) }
        let session = JobApplicationSession(storageURL: try storage(), session: network(), tailor: { _, _ in wrong })
        session.start(jobText: JobApplicationDemo.jobText, resumeText: JobApplicationDemo.resume)
        try await finish(session)
        XCTAssertFalse(session.hasSubmitted)
        XCTAssertTrue(session.error?.contains("incomplete draft") == true)
    }

    func testCancelDuringTailoringPreventsDelivery() async throws {
        let prepared = draft()
        JobApplicationTestProtocol.handler = { _, _ in XCTFail("Cancelled preparation must not submit"); throw URLError(.badURL) }
        let session = JobApplicationSession(storageURL: try storage(), session: network(), tailor: { _, _ in
            try await Task.sleep(nanoseconds: 2_000_000_000); return prepared
        })
        session.start(jobText: JobApplicationDemo.jobText, resumeText: JobApplicationDemo.resume)
        await Task.yield()
        session.cancel()
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertFalse(session.isBusy)
        XCTAssertFalse(session.hasSubmitted)
        XCTAssertTrue(session.error?.contains("paused") == true)
    }

    func testPersistenceFailureStopsBeforeAIAndDelivery() async throws {
        let file = try storage()
        try Data("not a directory".utf8).write(to: file)
        let prepared = draft()
        let session = JobApplicationSession(storageURL: file.appendingPathComponent("blocked.json"), session: network(), tailor: { _, _ in
            XCTFail("Initial persistence failure must prevent AI"); return prepared
        })
        session.start(jobText: JobApplicationDemo.jobText, resumeText: JobApplicationDemo.resume)
        XCTAssertNotNil(session.error)
        XCTAssertNil(session.applicationID)
    }

    func testCorruptSavedStateDoesNotSendOrRestartSilently() throws {
        let file = try storage()
        try Data("broken".utf8).write(to: file)
        let prepared = draft()
        let session = JobApplicationSession(storageURL: file, session: network(), tailor: { _, _ in
            XCTFail("A corrupt store must not cause submission"); return prepared
        })
        session.start(jobText: JobApplicationDemo.jobText, resumeText: JobApplicationDemo.resume)
        XCTAssertFalse(session.isBusy)
        XCTAssertTrue(session.error?.contains("restored") == true)
        session.reset()
        XCTAssertEqual(session.phase, .ready)
    }

    func testMissingKeyProducesActionableFailureWithoutSubmission() async throws {
        let session = JobApplicationSession(storageURL: try storage(), session: network(), tailor: { _, _ in
            throw OpenAIClient.ClientError.missingKey
        })
        session.start(jobText: JobApplicationDemo.jobText, resumeText: JobApplicationDemo.resume)
        try await finish(session)
        XCTAssertTrue(session.error?.contains("Settings") == true)
        XCTAssertFalse(session.hasSubmitted)
    }
}

private final class JobApplicationRequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Data] = []
    var bodies: [Data] { lock.lock(); defer { lock.unlock() }; return values }
    func append(_ body: Data) { lock.lock(); defer { lock.unlock() }; values.append(body) }
}

private final class JobApplicationTestProtocol: URLProtocol {
    static var handler: ((URLRequest, Data) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            var body = request.httpBody ?? Data()
            if body.isEmpty, let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4_096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count > 0 else { break }
                    body.append(buffer, count: count)
                }
            }
            guard let handler = Self.handler else { throw URLError(.resourceUnavailable) }
            let (status, data) = try handler(request, body)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
