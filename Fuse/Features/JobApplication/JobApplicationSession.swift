import Foundation
import Observation

struct JobApplicationReceipt: Codable, Equatable {
    let applicationID: String
    let receiptID: String
    let jobID: String
    let candidateName: String
    let receivedAt: String
    let status: String
    let destination: String
}

struct JobApplicationSubmission: Codable, Equatable {
    let applicationID: String
    let jobID: String
    let candidateName: String
    let email: String
    let resume: String
    let coverLetter: String
}

private struct SavedJobApplication: Codable {
    let applicationID: String
    let jobText: String
    let originalResume: String
    var draft: JobApplicationDraft?
    var submission: JobApplicationSubmission?
    var receipt: JobApplicationReceipt?
}

@MainActor @Observable
final class JobApplicationSession {
    enum Phase: Equatable {
        case ready, tailoring, filling, submitting, submitted, failed(String)
    }

    private(set) var phase: Phase = .ready
    let jobTitle = JobApplicationDemo.jobTitle
    let company = JobApplicationDemo.company
    let candidateName = JobApplicationDemo.candidateName
    private(set) var originalResume = JobApplicationDemo.resume
    private(set) var tailoredResume = ""
    private(set) var coverLetter = ""
    private(set) var changes: [String] = []
    private(set) var gaps: [String] = []
    private(set) var filledFieldCount = 0
    private(set) var receipt: JobApplicationReceipt?

    var isBusy: Bool { phase == .tailoring || phase == .filling || phase == .submitting }
    var hasSubmitted: Bool { receipt != nil && phase == .submitted }
    var canRetry: Bool { !isBusy && !hasSubmitted && saved != nil && !restoreFailed }
    var error: String? { if case .failed(let message) = phase { message } else { nil } }
    var applicationID: String? { saved?.applicationID }

    typealias Tailor = @MainActor (String, String) async throws -> JobApplicationDraft
    @ObservationIgnored private let tailor: Tailor
    @ObservationIgnored private let network: URLSession
    @ObservationIgnored private let storageURL: URL
    @ObservationIgnored private var saved: SavedJobApplication?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var attemptID: UUID?
    @ObservationIgnored private var restoreFailed = false

    init(
        storageURL: URL? = nil,
        session: URLSession? = nil,
        tailor: @escaping Tailor = { job, resume in
            try await JobApplicationTailoring.generate(job: job, resume: resume)
        }
    ) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        self.network = session ?? URLSession(configuration: configuration)
        self.tailor = tailor
        self.storageURL = storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JobApplication", isDirectory: true).appendingPathComponent("current.json")
        restore()
    }

    /// Invoked only by the app's foreground fold/Combine gate after both snapshots are ready.
    /// This session adds a second duplicate guard so repeated fold events cannot create extra applications.
    func start(jobText: String, resumeText: String) {
        guard !isBusy, !hasSubmitted, saved == nil, !restoreFailed else { return }
        do {
            try JobApplicationDemo.validateSources(job: jobText, resume: resumeText)
            let initial = SavedJobApplication(applicationID: UUID().uuidString,
                                              jobText: jobText, originalResume: JobApplicationDemo.resume)
            try persist(initial)
            saved = initial
            originalResume = initial.originalResume
            run()
        } catch { phase = .failed(Self.message(for: error)) }
    }

    /// Reuses a durably prepared payload and identifier after a timeout, cancellation or relaunch.
    /// An uncertain delivery never reruns AI or creates a different application.
    func retry() {
        guard !isBusy, !hasSubmitted, saved != nil, !restoreFailed else { return }
        run()
    }

    func cancel() {
        guard isBusy else { return }
        attemptID = nil
        task?.cancel()
        task = nil
        phase = .failed(saved?.submission == nil
            ? "Preparation paused. Retry to continue with the same application."
            : "Delivery may already have reached the demo inbox. Retry checks the same application without creating a duplicate.")
    }

    func reset() {
        // A request can reach the server even if its response is lost. Keep its identifier recoverable.
        guard !isBusy else { return }
        guard saved?.submission == nil || saved?.receipt != nil else {
            phase = .failed("Resolve the pending delivery with Retry before starting another application.")
            return
        }
        do {
            if FileManager.default.fileExists(atPath: storageURL.path) {
                try FileManager.default.removeItem(at: storageURL)
            }
            attemptID = nil
            task?.cancel()
            task = nil
            saved = nil
            receipt = nil
            filledFieldCount = 0
            originalResume = JobApplicationDemo.resume
            tailoredResume = ""
            coverLetter = ""
            changes = []
            gaps = []
            restoreFailed = false
            phase = .ready
        } catch { phase = .failed("The saved application could not be cleared. Try again after checking available storage.") }
    }

    private func run() {
        guard let existing = saved else { return }
        let attempt = UUID()
        attemptID = attempt
        phase = existing.submission == nil ? .tailoring : .submitting
        task = Task { [weak self] in
            guard let self else { return }
            do {
                var current = existing
                try JobApplicationDemo.validateSources(job: current.jobText, resume: current.originalResume)
                if current.submission == nil {
                    let draft = try await tailor(current.jobText, current.originalResume)
                    try checkAttempt(attempt)
                    let resume = try draft.validatedResume(from: current.originalResume)
                    current.draft = draft
                    current.submission = JobApplicationSubmission(
                        applicationID: current.applicationID, jobID: JobApplicationDemo.jobID,
                        candidateName: JobApplicationDemo.candidateName, email: JobApplicationDemo.email,
                        resume: resume, coverLetter: draft.coverLetter)
                    // A failed write must stop before the network request.
                    try persist(current)
                    saved = current
                    applyPresentation(current)
                }
                try checkAttempt(attempt)
                guard let submission = current.submission else { throw JobApplicationError.invalidReceipt }
                try validateSavedSubmission(submission, saved: current)
                phase = .filling
                filledFieldCount = 0
                for field in 1...4 {
                    try await Task.sleep(nanoseconds: 550_000_000)
                    try checkAttempt(attempt)
                    filledFieldCount = field
                }
                phase = .submitting
                let confirmed = try await deliver(submission)
                try checkAttempt(attempt)
                current.receipt = confirmed
                try persist(current)
                saved = current
                receipt = confirmed
                phase = .submitted
                task = nil
            } catch {
                guard attemptID == attempt, !Task.isCancelled else { return }
                phase = .failed(Self.message(for: error, during: phase))
                task = nil
            }
        }
    }

    private func checkAttempt(_ id: UUID) throws {
        try Task.checkCancellation()
        guard attemptID == id else { throw CancellationError() }
    }

    private func deliver(_ submission: JobApplicationSubmission) async throws -> JobApplicationReceipt {
        var request = URLRequest(url: JobApplicationDemo.submissionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(submission.applicationID, forHTTPHeaderField: "Idempotency-Key")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        request.httpBody = try encoder.encode(submission)
        let (data, response) = try await network.data(for: request, delegate: JobApplicationRedirectBlocker())
        guard let http = response as? HTTPURLResponse,
              http.url == JobApplicationDemo.submissionURL else { throw JobApplicationError.invalidReceipt }
        guard (200..<300).contains(http.statusCode) else { throw JobApplicationError.http(http.statusCode) }
        guard data.count < 32_768,
              let receipt = try? JSONDecoder().decode(JobApplicationReceipt.self, from: data) else {
            throw JobApplicationError.invalidReceipt
        }
        try validateReceipt(receipt, applicationID: submission.applicationID)
        return receipt
    }

    private func validateReceipt(_ receipt: JobApplicationReceipt, applicationID: String) throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.date(from: receipt.receivedAt) ?? ISO8601DateFormatter().date(from: receipt.receivedAt)
        guard UUID(uuidString: receipt.applicationID) == UUID(uuidString: applicationID),
              !receipt.receiptID.isEmpty, receipt.receiptID.count < 200,
              receipt.jobID == JobApplicationDemo.jobID,
              receipt.candidateName == JobApplicationDemo.candidateName,
              receipt.status == "received", receipt.destination == JobApplicationDemo.destination,
              timestamp != nil else { throw JobApplicationError.invalidReceipt }
    }

    private func validateSavedSubmission(_ submission: JobApplicationSubmission, saved: SavedJobApplication) throws {
        guard UUID(uuidString: saved.applicationID) != nil,
              submission.applicationID == saved.applicationID, submission.jobID == JobApplicationDemo.jobID,
              submission.candidateName == JobApplicationDemo.candidateName,
              submission.email == JobApplicationDemo.email, let draft = saved.draft,
              submission.resume == (try draft.validatedResume(from: saved.originalResume)),
              submission.coverLetter == draft.coverLetter else { throw JobApplicationError.invalidReceipt }
    }

    private func persist(_ value: SavedJobApplication) throws {
        do {
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: storageURL, options: .atomic)
            var url = directory
            var resources = URLResourceValues()
            resources.isExcludedFromBackup = true
            try? url.setResourceValues(resources)
        } catch { throw JobApplicationError.persistence }
    }

    private func restore() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            guard data.count < 1_000_000 else { throw JobApplicationError.invalidReceipt }
            let restored = try JSONDecoder().decode(SavedJobApplication.self, from: data)
            try JobApplicationDemo.validateSources(job: restored.jobText, resume: restored.originalResume)
            guard UUID(uuidString: restored.applicationID) != nil else { throw JobApplicationError.invalidReceipt }
            if let submission = restored.submission { try validateSavedSubmission(submission, saved: restored) }
            if let receipt = restored.receipt {
                guard restored.submission != nil else { throw JobApplicationError.invalidReceipt }
                try validateReceipt(receipt, applicationID: restored.applicationID)
            }
            saved = restored
            applyPresentation(restored)
            receipt = restored.receipt
            phase = restored.receipt != nil ? .submitted : .failed(restored.submission != nil
                ? "An application was prepared before FUSE closed. Retry safely to confirm its receipt."
                : "Preparation was interrupted. Retry to finish this application.")
        } catch {
            restoreFailed = true
            phase = .failed("The saved application could not be restored. Reset the demo to start again.")
        }
    }

    private func applyPresentation(_ value: SavedJobApplication) {
        filledFieldCount = value.submission == nil ? 0 : 4
        originalResume = value.originalResume
        tailoredResume = value.submission?.resume ?? ""
        coverLetter = value.draft?.coverLetter ?? ""
        changes = value.draft?.edits.map(\.reason) ?? []
        gaps = value.draft?.gaps ?? []
    }

    private static func message(for error: Error, during phase: Phase? = nil) -> String {
        if let known = error as? JobApplicationError { return known.localizedDescription }
        if let clientError = error as? OpenAIClient.ClientError {
            switch clientError {
            case .missingKey: return "Add your OpenAI API key in Settings, then retry. No application was sent."
            case .http(let status, _): return "AI preparation failed (\(status)). Check your connection and API settings, then retry."
            case .invalidImageCount, .invalidReference: return "The AI service could not read an input. Check your job and résumé, then retry."
            case .malformed: return "AI preparation returned an unreadable draft. Nothing was submitted; retry."
            case .invalidImageCount, .invalidReference: return "AI preparation could not use the attached images. Nothing was submitted; retry."
            }
        }
        if let networkError = error as? URLError {
            if phase == .tailoring {
                return "FUSE could not reach the AI service. Check your internet connection and retry. No application was sent."
            }
            switch networkError.code {
            case .cannotConnectToHost, .cannotFindHost:
                return "The local demo inbox is unavailable. Start the demo server on port 8777, then retry with the same application."
            default:
                return "The connection was interrupted. Retry safely; a prepared application keeps the same ID."
            }
        }
        return "This application could not finish. Retry to continue safely."
    }
}

private final class JobApplicationRedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // A compromised local endpoint must not redirect this payload to a real third-party service.
        completionHandler(nil)
    }
}
