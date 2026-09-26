import Foundation

// MARK: - Background fuse jobs
//
// One JSON file per invocation under Application Support/Fuse/jobs/<id>.json. The store gives
// the background intent a stable invocation ID (for exactly-once completion and later snippet
// actions) and survives the process being killed between invocation and card display.

struct FuseJob: Codable, Identifiable, Equatable {
    enum State: String, Codable {
        case pending, running, done, failed
    }

    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var instruction: String?
    var layout: FuseLayout
    var state: State
    var result: FuseResult?
    var error: String?

    init(id: UUID = UUID(), createdAt: Date = Date(), instruction: String?, layout: FuseLayout) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.instruction = instruction
        self.layout = layout
        self.state = .pending
    }

    var isFinished: Bool { state == .done || state == .failed }
}

actor FuseJobStore {
    static let shared = FuseJobStore()

    /// Jobs older than this are removed by `cleanup()`.
    static let expiry: TimeInterval = 24 * 60 * 60

    let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory()
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    nonisolated static func defaultDirectory() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        return base.appendingPathComponent("Fuse", isDirectory: true).appendingPathComponent("jobs", isDirectory: true)
    }

    // MARK: Create / update

    func create(instruction: String?, layout: FuseLayout) throws -> FuseJob {
        let job = FuseJob(instruction: instruction, layout: layout)
        try save(job)
        return job
    }

    func save(_ job: FuseJob) throws {
        try ensureDirectory()
        var copy = job
        copy.updatedAt = Date()
        let data = try encoder.encode(copy)
        try data.write(to: url(for: job.id), options: .atomic)
    }

    /// Apply `mutate` to the stored job and save it. Returns nil when the job does not exist.
    @discardableResult
    func update(id: UUID, _ mutate: (inout FuseJob) -> Void) throws -> FuseJob? {
        guard var job = load(id: id) else { return nil }
        mutate(&job)
        try save(job)
        return job
    }

    /// Mark a job done with its result, exactly once. Returns false if it was already finished
    /// (done or failed), in which case nothing is written.
    func complete(id: UUID, result: FuseResult) throws -> Bool {
        guard var job = load(id: id), !job.isFinished else { return false }
        job.state = .done
        job.result = result
        job.error = nil
        try save(job)
        return true
    }

    /// Mark a job failed, unless it already finished.
    @discardableResult
    func fail(id: UUID, error: String) throws -> Bool {
        guard var job = load(id: id), !job.isFinished else { return false }
        job.state = .failed
        job.error = error
        try save(job)
        return true
    }

    // MARK: Read

    func load(id: UUID) -> FuseJob? {
        guard let data = try? Data(contentsOf: url(for: id)) else { return nil }
        return try? decoder.decode(FuseJob.self, from: data)
    }

    func all() -> [FuseJob] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        return names.compactMap { name -> FuseJob? in
            guard name.hasSuffix(".json"), let id = UUID(uuidString: String(name.dropLast(5))) else { return nil }
            return load(id: id)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    /// The most recently created job, if any.
    func latest() -> FuseJob? {
        all().first
    }

    // MARK: Cleanup

    /// Remove jobs created more than `maxAge` before `now`. Returns the number removed.
    @discardableResult
    func cleanup(olderThan maxAge: TimeInterval = FuseJobStore.expiry, now: Date = Date()) -> Int {
        var removed = 0
        for job in all() where now.timeIntervalSince(job.createdAt) > maxAge {
            if (try? FileManager.default.removeItem(at: url(for: job.id))) != nil { removed += 1 }
        }
        return removed
    }

    // MARK: Files

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private func ensureDirectory() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path) {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
