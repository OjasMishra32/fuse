import Foundation

/// A deliberately fictional application target. This feature never submits to a real employer.
enum JobApplicationDemo {
    static let jobID = "bright-labs-pm-2026"
    static let jobTitle = "Product Manager, Merchant Growth"
    static let company = "Bright Labs"
    static let candidateName = "Alex Morgan"
    static let email = "alex.morgan@example.com"
    static let jobURL = URL(string: "http://127.0.0.1:8777/jobs/bright-labs-pm")!
    static let submissionURL = URL(string: "http://127.0.0.1:8777/api/demo/applications")!
    static let destination = "Bright Labs demo inbox"

    static let jobText = """
    BRIGHT LABS · DEMO JOB
    Job ID: bright-labs-pm-2026
    Product Manager, Merchant Growth
    San Francisco · Hybrid · Full time

    Bright Labs builds tools that help independent merchants turn visits into repeat customers.
    We are looking for a Product Manager to own merchant activation and checkout conversion.

    What you will do
    • Build a merchant growth roadmap with design, engineering, and analytics.
    • Interview merchants, identify onboarding friction, and run measurable experiments.
    • Use SQL and funnel analysis to prioritize opportunities and track checkout conversion.
    • Communicate decisions, evidence, and tradeoffs clearly across functions.

    What you bring
    • Product management experience shipping customer-facing products.
    • Evidence of improving conversion with experiments and customer research.
    • Comfortable using SQL, prioritizing roadmaps, and working with engineering and design.
    • International expansion and pricing experience are a bonus, not a requirement.

    Demo application: submit a résumé and a short cover letter to the local Bright Labs demo inbox.
    This is a fictional role. No real employer receives this application.
    """

    static let profile = "Product manager focused on useful customer experiences, clear priorities, and measurable product improvements."
    static let checkoutBullet = "Improved checkout conversion by 12% through funnel analysis and experiments with design and engineering."
    static let researchBullet = "Conducted 20 merchant interviews to identify onboarding friction and shape roadmap priorities."
    static let analyticsBullet = "Used SQL to investigate funnel drop-offs and shared experiment findings with cross-functional partners."
    static let editablePassages = [profile, checkoutBullet, researchBullet, analyticsBullet]

    static let resume = """
    ALEX MORGAN
    alex.morgan@example.com · San Francisco, CA
    FICTIONAL CANDIDATE · FUSE DEMO

    PROFILE
    \(profile)

    EXPERIENCE
    Product Manager · Cedar Commerce · 2022–2026
    • \(checkoutBullet)
    • \(researchBullet)
    • \(analyticsBullet)

    SKILLS
    Product discovery · SQL · Funnel analysis · Experimentation
    Roadmap prioritization · Cross-functional collaboration

    This fictional résumé is provided for the Bright Labs demo only.
    """

    /// Requiring the complete fixture prevents a real résumé with a stray demo marker from being sent.
    /// Job pages may contain HTML navigation text, but must include this job's identity and duties.
    static func validateSources(job: String, resume: String) throws {
        let normalizedResume = normalize(resume)
        guard normalizedResume == normalize(Self.resume) else {
            throw JobApplicationError.invalidSource("Use Alex Morgan’s unchanged demo résumé. Real or edited résumés are not automatically submitted by this demo.")
        }
        let jobLower = normalize(job).lowercased()
        guard jobLower.contains(jobID), jobLower.contains("bright labs"),
              jobLower.contains("product manager"), jobLower.contains("merchant"),
              jobLower.contains("fictional"), jobLower.contains("sql") else {
            throw JobApplicationError.invalidSource("Open the fictional Bright Labs job before applying. This demo only sends to its local demo inbox.")
        }
    }

    static func normalize(_ value: String) -> String {
        value.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }
}

enum JobApplicationError: LocalizedError {
    case invalidSource(String)
    case invalidDraft(String)
    case invalidReceipt
    case http(Int)
    case persistence

    var errorDescription: String? {
        switch self {
        case .invalidSource(let message), .invalidDraft(let message): message
        case .invalidReceipt: "The demo inbox did not return a valid receipt. Retry safely with the same application ID."
        case .http(let status): "The demo inbox returned \(status). Start the local demo server, then retry."
        case .persistence: "FUSE could not save the application state. Check available storage, then retry; a prepared application keeps its ID."
        }
    }
}
