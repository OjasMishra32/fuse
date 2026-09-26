import Foundation
import Observation
import Supabase

// MARK: - Supabase: fuse history + community feed
//
// One table, `public.fuses` (see supabase/schema.sql). Users are signed in anonymously so
// every row has an owner without an account flow. `artifact` is a jsonb column holding the
// `FuseArtifact` JSON exactly as the app encodes it, so a community row can be reopened.

/// A row of `public.fuses`. Column names are the property names.
struct RemoteFuse: Codable, Identifiable {
    var id: UUID
    var created_at: Date?
    var user_id: String?
    var device: String?
    var left_kind: String
    var left_title: String
    var right_kind: String
    var right_title: String
    var instruction: String?
    var recipe: String
    var title: String
    var summary: String
    var artifact: FuseArtifact?
    var is_public: Bool

    /// Lenient decoding: a half-filled row should never sink the whole feed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        created_at = try? c.decodeIfPresent(Date.self, forKey: .created_at)
        user_id = try? c.decodeIfPresent(String.self, forKey: .user_id)
        device = try? c.decodeIfPresent(String.self, forKey: .device)
        left_kind = try c.decodeIfPresent(String.self, forKey: .left_kind) ?? ""
        left_title = try c.decodeIfPresent(String.self, forKey: .left_title) ?? ""
        right_kind = try c.decodeIfPresent(String.self, forKey: .right_kind) ?? ""
        right_title = try c.decodeIfPresent(String.self, forKey: .right_title) ?? ""
        instruction = try? c.decodeIfPresent(String.self, forKey: .instruction)
        recipe = try c.decodeIfPresent(String.self, forKey: .recipe) ?? "fuse"
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Fused"
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        artifact = try? c.decodeIfPresent(FuseArtifact.self, forKey: .artifact)
        is_public = try c.decodeIfPresent(Bool.self, forKey: .is_public) ?? false
    }

    var leftKind: SurfaceKind? { SurfaceKind(rawValue: left_kind) }
    var rightKind: SurfaceKind? { SurfaceKind(rawValue: right_kind) }

    /// Symbol for the card: the artifact's own glyph, or sparkles when there is none.
    var symbol: String { artifact?.symbol ?? "sparkles" }

    /// Rebuilds a `FuseResult` the result screen can render.
    func toFuseResult() -> FuseResult {
        let inputs: [InputSummary] = [
            leftKind.map { InputSummary(kind: $0, title: left_title) },
            rightKind.map { InputSummary(kind: $0, title: right_title) }
        ].compactMap { $0 }
        var result = FuseResult(
            recipe: recipe,
            title: title,
            summary: summary,
            artifact: artifact ?? .markdown(summary.isEmpty ? title : summary),
            inputs: inputs,
            instruction: instruction
        )
        result.id = id
        result.createdAt = created_at ?? Date()
        return result
    }
}

/// Insert payload. `id` and `created_at` are left to the database defaults.
private struct NewFuseRow: Encodable {
    var user_id: String
    var device: String
    var left_kind: String
    var left_title: String
    var right_kind: String
    var right_title: String
    var instruction: String?
    var recipe: String
    var title: String
    var summary: String
    var artifact: FuseArtifact
    var is_public: Bool
}

@MainActor
@Observable
final class SupabaseService {
    static let shared = SupabaseService()

    private(set) var isConfigured = false
    /// Anonymous auth user id once `ensureSession()` has run.
    private(set) var userId: String?
    private(set) var isSyncing = false
    private(set) var lastRecordedAt: Date?
    var lastError: String?

    @ObservationIgnored private var client: SupabaseClient?
    @ObservationIgnored private var configuredURL: URL?
    @ObservationIgnored private var configuredKey: String?
    @ObservationIgnored private var configObserver: NSObjectProtocol?

    private init() {
        configObserver = NotificationCenter.default.addObserver(
            forName: AppConfig.didChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reconfigure() }
        }
        reconfigure()
    }

    /// One-line status for the Settings screen.
    var status: String {
        guard isConfigured else { return "Not configured · add project ref + anon key" }
        if let lastError { return lastError }
        if let userId { return "Connected · anon user \(userId.prefix(8))" }
        return "Ready · \(configuredURL?.host() ?? "supabase.co")"
    }

    // MARK: - Client

    /// Creates (or re-creates after a key change) the client. Returns nil when unconfigured.
    @discardableResult
    func reconfigure() -> SupabaseClient? {
        guard AppConfig.hasSupabase, let url = AppConfig.supabaseURL else {
            client = nil
            configuredURL = nil
            configuredKey = nil
            isConfigured = false
            userId = nil
            return nil
        }
        let key = AppConfig.supabaseAnonKey
        if let client, configuredURL == url, configuredKey == key { return client }
        let fresh = SupabaseClient(supabaseURL: url, supabaseKey: key)
        client = fresh
        configuredURL = url
        configuredKey = key
        isConfigured = true
        userId = nil
        lastError = nil
        return fresh
    }

    // MARK: - Auth

    /// Reuses a stored session or signs in anonymously. Sets `userId` on success.
    func ensureSession() async {
        guard let client = reconfigure() else { return }
        if let session = try? await client.auth.session {
            userId = session.user.id.uuidString
            return
        }
        do {
            let session = try await client.auth.signInAnonymously()
            userId = session.user.id.uuidString
            lastError = nil
        } catch {
            lastError = "Anonymous sign-in failed — enable Anonymous sign-ins under Authentication › Providers. (\(error.localizedDescription))"
        }
    }

    // MARK: - Writes

    /// Stores a fuse. Errors are swallowed into `lastError`; the fuse itself is never blocked.
    func record(_ result: FuseResult, device: String, isPublic: Bool) async {
        guard let client = reconfigure() else { return }
        isSyncing = true
        defer { isSyncing = false }

        await ensureSession()
        guard let userId else { return }

        let left = result.inputs.first
        let right = result.inputs.count > 1 ? result.inputs[1] : nil
        let row = NewFuseRow(
            user_id: userId,
            device: device,
            left_kind: left?.kind.rawValue ?? "unknown",
            left_title: left?.title ?? "",
            right_kind: right?.kind.rawValue ?? "unknown",
            right_title: right?.title ?? "",
            instruction: result.instruction,
            recipe: result.recipe,
            title: result.title,
            summary: result.summary,
            artifact: result.artifact,
            is_public: isPublic
        )
        do {
            try await client.from("fuses").insert(row).execute()
            lastRecordedAt = Date()
            lastError = nil
        } catch {
            lastError = "Couldn't save fuse: \(error.localizedDescription)"
        }
    }

    // MARK: - Reads

    /// Public fuses, newest first. Readable with the anon key alone (no session required).
    func fetchCommunity(limit: Int = 20) async -> [RemoteFuse] {
        guard let client = reconfigure() else { return [] }
        do {
            let rows: [RemoteFuse] = try await client
                .from("fuses")
                .select()
                .eq("is_public", value: true)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            lastError = nil
            return rows
        } catch {
            lastError = "Couldn't load community: \(error.localizedDescription)"
            return []
        }
    }

    /// This device's own fuses (public or not), newest first.
    func fetchMine(limit: Int = 50) async -> [RemoteFuse] {
        guard let client = reconfigure() else { return [] }
        await ensureSession()
        guard let userId else { return [] }
        do {
            let rows: [RemoteFuse] = try await client
                .from("fuses")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            lastError = nil
            return rows
        } catch {
            lastError = "Couldn't load your fuses: \(error.localizedDescription)"
            return []
        }
    }
}
