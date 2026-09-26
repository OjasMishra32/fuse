import Foundation

// MARK: - Demo scenarios
//
// Each scenario seeds both panes with real, concrete content so the router has something to
// cross-reference. Pick one from the demo menu (or `fuse://demo/<id>` / the "Run demo" intent),
// then fold. `instruction` is optional — nil means "infer the fuse from the relationship".
//
// NOTE for the calendar surface: the "sample" week should include at least one event that
// overlaps Fri Nov 20 – Sun Nov 22, 2026 (e.g. a Friday 10:00 dentist, a Saturday 7 PM dinner)
// so the "Fold it into my week" scenario produces a visible conflict warning.

struct DemoScenario: Identifiable {
    struct Input {
        var kind: SurfaceKind
        var preset: SurfacePreset
    }

    let id: String
    let title: String
    /// ≤ 8 words describing the fuse, e.g. "Attraction page + map → itinerary".
    let subtitle: String
    /// SF Symbol.
    let symbol: String
    let left: Input
    let right: Input
    let instruction: String?

    static var all: [DemoScenario] { sections.flatMap(\.scenarios) }

    struct Section: Identifiable {
        let title: String
        let scenarios: [DemoScenario]
        var id: String { title }
    }

    /// Grouped by the relationship between the two screens.
    static var sections: [Section] {
        [
            Section(title: "Featured", scenarios: core + more),
            Section(title: "Places and plans", scenarios: places),
            Section(title: "Time and commitments", scenarios: time),
            Section(title: "Review and compare", scenarios: review),
            Section(title: "Make and create", scenarios: make),
        ]
    }

    static let core: [DemoScenario] = [
        DemoScenario(
            id: "theme-park",
            title: "Theme park, one day",
            subtitle: "Attraction page + map → itinerary",
            symbol: "ticket",
            left: .web("https://en.wikipedia.org/wiki/Islands_of_Adventure"),
            right: .place("Universal Islands of Adventure", 28.4711, -81.4712),
            instruction: nil
        ),
        DemoScenario(
            id: "week",
            title: "Fold it into my week",
            subtitle: "Conference email + calendar → event",
            symbol: "calendar.badge.plus",
            left: .notes(DemoText.conferenceEmail),
            right: .sampleCalendar,
            instruction: nil
        ),
        DemoScenario(
            id: "grade",
            title: "Grade my practice test",
            subtitle: "Practice test + your answers → grade",
            symbol: "graduationcap",
            left: .notes(DemoText.practiceTest),
            right: .notes(DemoText.studentAnswers),
            instruction: nil
        ),
        DemoScenario(
            id: "cover-email",
            title: "Cover email",
            subtitle: "Job posting + resume → cover email",
            symbol: "envelope",
            left: .notes(DemoText.jobPosting),
            right: .notes(DemoText.resume),
            instruction: nil
        ),
        DemoScenario(
            id: "redline",
            title: "Redline",
            subtitle: "Vendor contract + policy → redline",
            symbol: "pencil.and.list.clipboard",
            left: .notes(DemoText.vendorContract),
            right: .notes(DemoText.procurementPolicy),
            instruction: nil
        ),
        DemoScenario(
            id: "route",
            title: "Route my day",
            subtitle: "Calendar + map → routed day",
            symbol: "arrow.triangle.turn.up.right.diamond",
            left: .sampleCalendar,
            right: .place("Y Combinator", 37.7760, -122.3969),
            instruction: "Order my day geographically and tell me when to leave for each stop"
        ),
        DemoScenario(
            id: "contradictions",
            title: "Contradictions",
            subtitle: "Wikipedia + blog draft → fact-check",
            symbol: "exclamationmark.triangle",
            left: .web("https://en.wikipedia.org/wiki/IPhone"),
            right: .notes(DemoText.blogDraft),
            instruction: nil
        ),
        DemoScenario(
            id: "pitch",
            title: "Presentation from notes",
            subtitle: "Messy notes + article → 6-slide pitch",
            symbol: "rectangle.on.rectangle",
            left: .notes(DemoText.startupNotes),
            right: .web("https://en.wikipedia.org/wiki/Foldable_smartphone"),
            instruction: "Make a 6-slide pitch"
        )
    ]

    static func named(_ id: String) -> DemoScenario? {
        all.first { $0.id == id }
    }
}

// MARK: - Input helpers

private extension DemoScenario.Input {
    static func web(_ string: String) -> Self {
        .init(kind: .web, preset: .url(URL(string: string)!))
    }

    static func notes(_ text: String) -> Self {
        .init(kind: .notes, preset: .text(text))
    }

    static func place(_ name: String, _ latitude: Double, _ longitude: Double) -> Self {
        .init(kind: .maps, preset: .place(name: name, latitude: latitude, longitude: longitude))
    }

    /// The calendar surface loads its sample week for any preset.
    static var sampleCalendar: Self {
        .init(kind: .calendar, preset: .text("sample"))
    }
}

// MARK: - Scenario text

private enum DemoText {

    static let conferenceEmail = """
    From: Swiftsonic Team <hello@swiftsonic.dev>
    To: Maya Chen
    Subject: You're confirmed — Swiftsonic 2026, Nashville

    Hi Maya,

    You're registered for Swiftsonic 2026, November 20–22, at the Music City Center, 201 Rep. John Lewis Way S, Nashville, TN 37203.

    Schedule at a glance
    • Fri Nov 20 — Doors 8:30 AM. Opening keynote 9:30 AM (Davidson Ballroom). Sessions until 5:30 PM. Welcome party 7:00 PM at Assembly Food Hall (5th + Broadway).
    • Sat Nov 21 — Doors 8:30 AM. Workshops 9:00 AM–12:30 PM. Afternoon tracks 1:30–5:00 PM. Speaker dinner (invite only) 7:00 PM, The Catbird Seat.
    • Sun Nov 22 — Half day. Community talks 9:00 AM–12:30 PM. Closing remarks 12:30 PM.

    Badge pickup opens Thursday Nov 19, 4:00–7:00 PM at the Broadway entrance. Bring photo ID.

    Speaker note: your talk "Hinge as Input" is scheduled Sat Nov 21, 2:15–2:45 PM, Room 104B. Please arrive 20 minutes early for A/V check.

    Hotel block at the Omni Nashville (250 Rep. John Lewis Way S), a 3-minute walk from the venue. The Swiftsonic rate expires Oct 31.

    Questions? Just reply to this email.

    — The Swiftsonic Team
    """

    static let practiceTest = """
    AP PHYSICS C / CALCULUS — PRACTICE TEST 3
    Use g = 10 m/s². Show units. 6 questions, 30 minutes.

    1. A ball is thrown straight up at 20 m/s. Ignoring air resistance, how long until it returns to the height it was thrown from?

    2. A 2.0 kg block on a frictionless horizontal surface is pushed by a constant 6.0 N horizontal force. What is its acceleration?

    3. Differentiate: f(x) = x³ − 4x² + 7x − 2. Give f′(x).

    4. Evaluate the definite integral ∫₀² 3x² dx.

    5. A 0.50 kg cart moving at 4.0 m/s collides with a 1.5 kg cart at rest and the two stick together. What is their common speed after the collision?

    6. A spring with spring constant k = 200 N/m is compressed 0.10 m from its natural length. How much elastic potential energy is stored?

    ANSWER KEY
    1. 4.0 s — time to the top is v/g = 2.0 s; the round trip is twice that.
    2. 3.0 m/s² — a = F/m = 6.0 / 2.0.
    3. f′(x) = 3x² − 8x + 7.
    4. 8 — antiderivative x³ evaluated from 0 to 2 gives 8 − 0.
    5. 1.0 m/s — momentum is conserved: 0.50 × 4.0 = 2.0 kg·m/s, shared by 2.0 kg.
    6. 1.0 J — U = ½ k x² = ½ × 200 × (0.10)².
    """

    static let studentAnswers = """
    Practice Test 3 — my answers (Maya)

    1. t = v/g = 20/10 = 2.0 s
    2. a = F/m = 6.0/2.0 = 3.0 m/s²
    3. f′(x) = 3x² − 8x + 7
    4. [x³] from 0 to 2 = 8 − 0 = 8
    5. p before = 0.5 × 4 = 2.0. After: 2.0 / (0.5 + 1.5) = 1.0 m/s
    6. U = kx² = 200 × 0.01 = 2.0 J

    Felt shaky on 1 and 6. Pretty sure about the rest.
    """

    static let jobPosting = """
    Hinge Labs — iOS Engineer (Foldables)
    San Francisco, CA · Hybrid · Full-time · $150k–$190k + equity

    Hinge Labs builds software that only makes sense on a phone that folds. We are 9 people, backed by Y Combinator, and shipping our first app on the iPhone Duo this fall. You will own big pieces of the product from day one.

    What you'll do
    • Design and ship SwiftUI interfaces that adapt to the hinge angle, the division region, and the cover display
    • Build the interaction layer: gestures, haptics, and animations that make the fold feel like an input
    • Work directly with our designer and founders; ship weekly

    What we're looking for
    • 2+ years building iOS apps in Swift, and at least one app you shipped to the App Store
    • Deep SwiftUI: Observation, custom layouts, animation, and view performance
    • Comfort with async/await, structured concurrency, and networking against JSON APIs
    • Experience integrating an LLM or vision API into a product (OpenAI, Anthropic, or on-device models)
    • Strong product taste: you can argue for or against a feature with the user in mind
    • Bonus: MapKit, EventKit, App Intents, or hackathon wins

    Apply: send a short note and a link to something you built to jobs@hingelabs.com. Tell us what you'd build for a phone with two screens.
    """

    static let resume = """
    MAYA CHEN
    Austin, TX · maya.chen.dev@gmail.com · github.com/mayachen · PocketPrompt on the App Store

    EDUCATION
    B.S. Computer Science, University of Texas at Austin — May 2026. GPA 3.8.
    Coursework: Mobile Computing, Distributed Systems, Human-Computer Interaction.

    EXPERIENCE
    iOS Engineering Intern — Notion, San Francisco (Jun–Aug 2025)
    • Rebuilt the mobile database-view toolbar in SwiftUI with @Observable models; cut view-body re-evaluations 40% (measured in Instruments).
    • Shipped Live Activities for reminders to 100% of iOS users; added Lock Screen widgets driven by App Intents.
    • Wrote the team's first snapshot-test suite for SwiftUI components (210 tests).

    iOS Intern — Whole Foods Market, Austin (Jun–Aug 2024)
    • Built the in-store map with MapKit: annotated aisles, live sale overlays, indoor positioning.
    • Migrated 14 UIKit screens to SwiftUI; owned the async/await refactor of the store-locator networking layer.

    PROJECTS
    PocketPrompt — App Store, 4.8 stars (1,200 ratings), 30k downloads. A SwiftUI app that turns screenshots into structured notes with the OpenAI vision API. Share Extension, Shortcuts actions, CloudKit sync. Solo-built.
    HackTX 2025 — 1st place, Best Mobile. A two-person split-screen study tool built in 36 hours.

    SKILLS
    Swift, SwiftUI, Observation, Swift Concurrency, UIKit, MapKit, EventKit, WidgetKit, App Intents, CloudKit, Core Data, XCTest, Instruments, Git, Figma. Some TypeScript and Python.
    """

    static let vendorContract = """
    MASTER SERVICES AGREEMENT — Northwind Analytics, Inc. ("Vendor") and Acme Robotics, Inc. ("Customer")
    Excerpt: Sections 4, 7, 9, 11, 12

    4. Term and Renewal. The Initial Term is twelve (12) months from the Effective Date. This Agreement shall automatically renew for successive twelve (12) month Renewal Terms unless either party gives written notice of non-renewal at least ninety (90) days before the end of the then-current term.

    7. Termination for Convenience. Customer may terminate this Agreement for convenience upon sixty (60) days' prior written notice to Vendor, and shall pay all fees for the remainder of the then-current term as an early termination fee.

    9. Limitation of Liability. Vendor's aggregate liability arising out of or related to this Agreement shall not exceed the fees paid by Customer in the three (3) months preceding the claim. Customer's liability to Vendor shall be unlimited.

    11. Intellectual Property. All deliverables, work product, reports, models, and derived data created in the course of the Services, including any customizations built on Customer data, shall be the sole and exclusive property of Vendor. Customer receives a non-exclusive, non-transferable license to use the deliverables during the Term.

    12. Payment. Vendor shall invoice annually in advance. Invoices are due net ninety (90) days from the invoice date. Late payments accrue interest at 1.5% per month.
    """

    static let procurementPolicy = """
    ACME ROBOTICS — Vendor Contract Standards (Procurement Policy PP-7, rev. March 2026)
    Applies to every SaaS and professional-services agreement over $25,000 per year. Deviations require written approval from the General Counsel.

    1. Term. No automatic renewal. Every renewal requires an affirmative written renewal signed by Procurement. Any notice period for non-renewal may not exceed thirty (30) days.

    2. Termination. Acme must be able to terminate for convenience on no more than thirty (30) days' written notice, with fees prorated to the termination date. No early-termination fees.

    3. Liability. Each party's aggregate liability must be capped at the fees paid or payable in the twelve (12) months preceding the claim, applied mutually. Unlimited liability for Acme is never acceptable. Standard carve-outs (breach of confidentiality, IP indemnity, gross negligence, willful misconduct) are permitted.

    4. Intellectual Property. Acme owns all deliverables, work product, and anything derived from Acme data. Vendor may retain ownership of its pre-existing platform and tools only, and grants Acme a perpetual, royalty-free license to any vendor tools embedded in deliverables.

    5. Payment. Standard terms are Net-45 from receipt of a correct invoice; Accounts Payable cannot process other terms without CFO approval. Invoicing quarterly in arrears is preferred; never more than one quarter in advance. Late-payment interest may not exceed 1.0% per month.
    """

    static let blogDraft = """
    Draft — "Why the iPhone still matters" (blog post, needs a fact-check before Tuesday)

    It's easy to forget how strange the iPhone looked in 2007. Steve Jobs unveiled it on stage at WWDC in June 2007, calling it a widescreen iPod, a phone, and an internet communicator in one device. The original model had a 4-inch multi-touch display, a 2-megapixel camera, and no physical keyboard, which most reviewers thought was suicidal. It went on sale in the United States on June 29, 2007, exclusively on AT&T (then Cingular), and shipped with the App Store, so third-party developers could sell software from day one. Time named it Invention of the Year. Nineteen years later the shape of the phone is basically unchanged, which is why the iPhone Duo's fold is the first time the object itself has really changed.
    """

    static let startupNotes = """
    startup idea — working name "Seam" (or Fold?? Hinge? check trademarks)

    - the fold is a *gesture* nobody is using. every foldable app just does "bigger screen" or "two apps side by side". boring
    - idea: apps where closing the phone DOES something. fold = commit. like slamming a laptop shut but useful
    - e.g. two screens → one result. page + map → plan. email + calendar → event. test + answers → grade.
    - why now: iphone duo ships this year. onHingeChange in iOS 27.1 = first time apple gave devs the live hinge angle. android foldables had this for 5 yrs but nobody built the interaction layer
    - market: foldables still single digit % of smartphones — grab shipment numbers from the wikipedia page. samsung / huawei / google already there, apple = the mainstream moment
    - biz model: pro tier (unlimited fuses, $6.99/mo via revenuecat) now, then an sdk so other apps can register "surfaces"
    - team: 4 of us — 2 iOS (ex-Notion, ex-Whole Foods interns), 1 designer, 1 backend. built v1 in a weekend at bitrig hacks
    - risks: apple could sherlock it. answer: we're the interaction layer not the phone, move to the sdk fast
    - ask: $500k pre-seed, 12 months runway, sdk by q2 2027
    - demo line: "the hinge is not navigation. it is the command."
    """
}
