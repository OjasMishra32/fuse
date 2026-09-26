import Foundation
import UIKit

// MARK: - Review scenarios
//
// Two classes: "Reference + Draft -> Correction" and "Two of a kind -> Verdict".
// Expected artifacts: diff (redline), grade, code, table (comparison or contradictions), checklist.
// Every scenario needs both screens live at once: one side is the standard, the other is judged by it.

extension DemoScenario {
    static let review: [DemoScenario] = [
        DemoScenario(
            id: "review-style-redline",
            title: "Style guide redline",
            subtitle: "Style guide + essay draft → redline",
            symbol: "text.badge.checkmark",
            left: .init(kind: .notes, preset: .text("""
                House style, Gator Review (student op-ed section)

                - Voice: first person plural is banned. Say "I" or name the group.
                - Sentences: aim for 20 words or fewer. Never open with "It is" or "There are".
                - Numbers: spell out one through nine, digits for 10 and up. Percentages always digits with the % sign.
                - Titles: Dr. or Prof. only on first mention, surname alone after that.
                - No passive voice in the lede. Passive allowed later only when the actor is unknown.
                - Banned words: utilize, impactful, leverage (as a verb), very, really, in order to.
                - Oxford comma: yes, always.
                - Quotes: attribution after the quote, "said" only. Not "stated", "claimed", "opined".
                - Campus names: "Reitz Union", "Library West", "Turlington" without "Hall".
                - Dates: month day, no ordinal. October 3, not October 3rd.
                - Every op-ed ends with one concrete ask of the reader, in one sentence.
                """)),
            right: .init(kind: .notes, preset: .text("""
                Draft: Why the Reitz Union needs later hours (op-ed, first 200 words)

                It is no secret that we students are stuck. Library West closes at 2 a.m. during finals, but the Reitz Union locks its doors at 10 p.m. on weeknights, which really doesn't make sense for a campus of 60,000 people. There are 3 study lounges inside the Union that sit empty for 8 hours every night while students crowd into the library stairwells in order to find an outlet.

                Dr. Angela Ruiz, who runs student affairs, stated that the building "could not be staffed safely past ten" when we asked her on October 3rd. That claim was not backed up by any numbers. Twenty two percent of respondents to our survey said they would utilize the Union after midnight at least twice a week, and 41% said the lack of late space was very impactful on their grades.

                The plan was very obviously left unfinished by the administration. We think it is time to leverage student government to demand a pilot: keep the ground floor open until 2 a.m. during the last 3 weeks of each semester.
                """)),
            instruction: "Redline the draft against the style guide. Show every change as a diff and name the rule each one breaks."
        ),
        DemoScenario(
            id: "review-mockup-code",
            title: "Mockup to code",
            subtitle: "Mockup notes + SwiftUI file → matching code",
            symbol: "chevron.left.forwardslash.chevron.right",
            left: .init(kind: .notes, preset: .text("""
                Mockup: Order summary card (Figma frame "Checkout / Summary v3")

                - Rounded card, 16 pt corner radius, secondary system background, 16 pt padding all around.
                - Top row: small caps label "ORDER SUMMARY" in caption font, secondary color, left aligned. On the right of the same row, the item count as a capsule badge, e.g. "3 items", tinted accent.
                - Below: one line per item. Left: item name, body font. Right: price, monospaced digits, right aligned. Rows separated by 8 pt.
                - A thin divider after the items.
                - Subtotal row and Shipping row in secondary color, subheadline font. Shipping shows "Free" in green when it is zero.
                - Total row: "Total" in headline font on the left, amount in title2 bold on the right, both primary color.
                - Bottom: full width button "Place order", prominent bordered style, 44 pt tall, accent tint. Disabled when there are no items.
                - Everything uses Dynamic Type. The card should not exceed 420 pt wide on iPad and should center itself.
                """)),
            right: .init(kind: .notes, preset: .text("""
                // OrderSummaryCard.swift (current implementation, does not match the mockup yet)
                import SwiftUI

                struct OrderLine: Identifiable {
                    let id = UUID()
                    let name: String
                    let price: Decimal
                }

                struct OrderSummaryCard: View {
                    let lines: [OrderLine]
                    let shipping: Decimal
                    var onPlaceOrder: () -> Void

                    private var subtotal: Decimal { lines.reduce(0) { $0 + $1.price } }
                    private var total: Decimal { subtotal + shipping }

                    var body: some View {
                        VStack(alignment: .leading) {
                            Text("Order summary")
                                .font(.headline)
                            ForEach(lines) { line in
                                HStack {
                                    Text(line.name)
                                    Spacer()
                                    Text(line.price, format: .currency(code: "USD"))
                                }
                            }
                            Text("Subtotal")
                            Text(subtotal, format: .currency(code: "USD"))
                            Text("Shipping")
                            Text(shipping, format: .currency(code: "USD"))
                            Text("Total")
                                .font(.title3)
                            Text(total, format: .currency(code: "USD"))
                            Button("Place order") { onPlaceOrder() }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                    }
                }
                """)),
            instruction: "Rewrite the view so it matches the mockup exactly. Return the full file, then a short list of what changed."
        ),
        DemoScenario(
            id: "review-rubric-grade",
            title: "Grade the writeup",
            subtitle: "Rubric + project writeup → grade",
            symbol: "graduationcap",
            left: .init(kind: .notes, preset: .text("""
                CEN3031 final project rubric (100 points)

                1. Problem statement (10): clear user, clear pain, measurable goal. Full marks need a named user segment and one metric.
                2. Architecture (20): diagram or prose that names every component and how data flows. Deduct 5 if persistence is not addressed, 5 if auth is hand-waved.
                3. Implementation (30): working demo, readable code, tests. 10 for demo, 10 for code quality, 10 for tests (0 if no tests, 5 if only happy path).
                4. Evaluation (20): did they measure anything? 20 needs a baseline, a result, and an honest limitation. 10 if results only. 0 if "it works great".
                5. Teamwork and process (10): commit history from every member, issues or a board, at least two retro notes.
                6. Writing (10): under 1500 words, headings, no typos, citations for any borrowed code or library claims.
                Late penalty: 10 per day. Hard cap: 0 after 3 days.
                Grade bands: A 90+, B 80 to 89, C 70 to 79, D 60 to 69.
                """)),
            right: .init(kind: .notes, preset: .text("""
                GatorPark: find parking on campus before you arrive
                Team: Ojas, Lena, Marcus. Submitted 1 day late (approved extension pending).

                Problem. Commuter students circle the Reitz garage for 15 minutes on average at 9 a.m. We want to cut that to under 5 by showing live occupancy per garage.

                Architecture. iOS app in SwiftUI talks to a FastAPI backend. The backend polls the UF Transportation occupancy feed every 60 seconds and caches counts in Redis. APNs push when a starred garage drops below 90% full. Users sign in with UF SSO (not finished, the demo uses a hardcoded test user). Counts are not stored long term.

                Implementation. Demo video attached, 3 min. Code on GitHub, 46 commits. We have 9 pytest tests for the parsing and caching layer. No UI tests. Marcus did the backend, Lena the app, Ojas the parser and alerts.

                Evaluation. We asked 12 friends to use it for a week. 9 said it saved them time. We did not measure actual circling time before and after. It works great for the two garages we support, but the feed is delayed by up to 4 minutes at peak so the count can be wrong.

                Process. GitHub Projects board with 31 issues. One retro after the midpoint.

                Word count: about 900.
                """)),
            instruction: "Grade this against the rubric. Points per section with a one-line reason, the late penalty, the total, and the letter grade."
        ),
        DemoScenario(
            id: "review-brand-diff",
            title: "On-brand slides",
            subtitle: "Brand guidelines + slide copy → diff",
            symbol: "paintbrush",
            left: .init(kind: .notes, preset: .text("""
                Fuse brand voice and naming, v2 (marketing)

                Product name: always "Fuse", never "FUSE" or "the Fuse app". The verb is "fuse" lowercase: "fuse two screens", never "Fuse it".
                Tagline: "Two screens. One answer." Exactly that punctuation. Never rewrite it.
                Tone: plain, confident, short. No exclamation marks. No "revolutionary", "game-changing", "seamless", "powerful", "AI-powered".
                We say "the other screen", not "the second screen" or "screen B".
                We say "result", not "output". We say "surface", not "panel" or "pane".
                Never make claims about speed with numbers unless legal has approved the benchmark. "Fast" alone is fine.
                Device names: Surface Duo, Galaxy Z Fold 6 (with the space), Pixel 9 Pro Fold. Never "foldable phone" as a category name, use "folding phones".
                Capitalization: sentence case for all headlines and buttons. Title Case is only for the product name.
                Pricing: "Fuse Pro" is the paid tier. Never "Premium" or "Plus". Free tier is just "free", lowercase.
                """)),
            right: .init(kind: .notes, preset: .text("""
                Deck: Fuse launch, 6 slides (speaker: Sam)

                Slide 1
                FUSE: Two Screens, One Answer!
                The Revolutionary AI-Powered Assistant For Foldable Phones

                Slide 2
                The Problem
                You have a page on screen A and a note on screen B. Copying between them is slow and painful. Every foldable phone owner knows this.

                Slide 3
                The Solution
                Fuse it. Fuse reads both panels at once and produces a seamless output in under 2 seconds.

                Slide 4
                Who It's For
                Galaxy ZFold 6, Pixel 9 Pro Fold and Surface Duo owners who live in two apps at once.

                Slide 5
                Pricing
                Free: 3 fuses a day. Fuse Premium: unlimited, $4.99 a month.

                Slide 6
                Try It Today!
                Download The Fuse App and fuse your first two screens.
                """)),
            instruction: "Diff the slide copy against the brand guide. Strike what breaks a rule, insert the fix, cite the rule."
        ),
        DemoScenario(
            id: "review-lease-checklist",
            title: "Lease pushback",
            subtitle: "Lease + tenant rights → pushback checklist",
            symbol: "doc.text",
            left: .init(kind: .document, preset: .text("""
                RESIDENTIAL LEASE (excerpt)
                Premises: 812 SW 9th Rd, Unit 14, Gainesville, FL. Landlord: Sable Oak Holdings LLC.
                Term: August 15, 2026 through August 14, 2027. Rent: $1,450.00 per month.

                5. Security Deposit. Tenant shall deposit $2,900.00 (two months' rent). Landlord may hold it in its general operating account and shall return any balance within 60 days after Tenant vacates.

                7. Entry. Landlord or its agents may enter the Premises at any time to inspect, show, or repair, with notice when practical.

                9. Late Fees. Rent unpaid by the 2nd incurs a late fee of $150 plus $25 per additional day.

                11. Repairs. Tenant pays for all repairs under $400, including plumbing, appliances, and HVAC. Landlord addresses other repairs within a reasonable time.

                13. Early Termination. If Tenant vacates early for any reason, Tenant owes all remaining rent for the Term and forfeits the deposit.

                16. Guests. A guest staying more than 3 nights in a month is an unauthorized occupant and a default.

                19. Waiver. Tenant waives the right to a jury trial and any claim for attorney's fees against Landlord.

                21. Renewal. This Lease automatically renews for 12 months unless Tenant gives 90 days' written notice.
                """)),
            right: .init(kind: .notes, preset: .text("""
                Florida tenant rights, notes from the UF Student Legal Services handout (Ch. 83, Fla. Stat.)

                - Deposit: must sit in a separate Florida account (no commingling) or be bonded, with written notice of which within 30 days. Return within 15 days if no claim, or an itemized claim by certified mail within 30 days.
                - Entry: reasonable notice, at least 12 hours, between 7:30 a.m. and 8 p.m. except emergencies.
                - Late fees: no statutory cap, but courts strike penalty fees. $150 plus daily fees on $1,450 rent is likely unenforceable.
                - Repairs: landlord must keep plumbing, structure, and required appliances working (83.51). Cannot shift these to the tenant.
                - Early termination: landlord must try to re-rent. Cannot collect all remaining rent and keep the deposit, that is double recovery. Liquidated damages only valid if capped at 2 months and signed as a separate addendum.
                - Jury and fee waivers: 83.47 voids any clause that waives tenant rights or limits landlord liability. Attorney's fees are mutual (83.48).
                - Auto renewal: 60 days is the most a landlord can require for non-renewal notice on a yearly lease.
                - Guests: limits are legal but 3 nights a month is unusually strict, ask for 14.
                """)),
            instruction: "Checklist of the clauses I should push back on before signing. For each: the clause number, why, and the sentence to ask for instead."
        ),
        DemoScenario(
            id: "review-laptops",
            title: "Two laptops, one table",
            subtitle: "MacBook Air + Surface Laptop → table",
            symbol: "tablecells",
            left: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/MacBook_Air")!)),
            right: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/Surface_Laptop")!)),
            instruction: "Compare the current generation of each: chip, RAM and storage options, display, weight, battery, ports, starting price. End with a verdict row for a CS student."
        ),
        DemoScenario(
            id: "review-apartments",
            title: "Hidden apartment costs",
            subtitle: "Listing A + Listing B → cost table",
            symbol: "house",
            left: .init(kind: .notes, preset: .text("""
                Listing A: The Standard at Gainesville, 1 bed 1 bath, 640 sq ft
                Rent: $1,695/month, 12 month lease starting August 1
                "Fully furnished, resort pool, rooftop study lounge, 24 hour gym. Steps from campus."
                Application fee $75, admin fee $250 (non-refundable), security deposit $500.
                Utilities: water, sewer, trash billed back monthly through Conservice, average $58. Electric through GRU in your name, they say average $90 in summer. Internet included (Xfinity 300 Mbps).
                Parking: garage $125/month, no street parking.
                Pets: $350 fee plus $35/month pet rent.
                Renters insurance required, $100k liability minimum, about $15/month.
                Lease break: 2 months rent plus forfeiture of deposit.
                Move-in special: first month free if signed by June 30 (applied as a credit spread across 12 months, not up front).
                """)),
            right: .init(kind: .notes, preset: .text("""
                Listing B: 2216 NW 2nd Ave, upstairs unit of a duplex, 1 bed 1 bath, 720 sq ft
                Rent: $1,250/month, 12 month lease starting August 1, private landlord (Dana, 352 number)
                Unfurnished. Window AC units, no central air. Washer and dryer in the unit. Small fenced yard shared with downstairs.
                Deposit: one month ($1,250). No application fee. No admin fee.
                Utilities: tenant pays everything in their own name. GRU electric plus water plus sewer, previous tenant said $140 to $190 a month in summer with the window units running. Internet not included, Cox about $65.
                Parking: driveway, free, two spots.
                Pets: allowed, no fee, "just don't let it wreck the yard".
                Renters insurance not required.
                Lease break: 60 days notice and you are out, deposit returned if the place is clean.
                About 1.4 miles to Turlington, 9 minutes by bike, bus 5 stops at the corner.
                Furniture I would need to buy: bed, desk, couch, roughly $900 used.
                """)),
            instruction: "Table of the real monthly cost of each, including every hidden fee, with a car and a dog. Then a 12-month total row and which one wins."
        ),
        DemoScenario(
            id: "review-offers",
            title: "Two offers, one table",
            subtitle: "Offer 1 + Offer 2 → comparison table",
            symbol: "briefcase",
            left: .init(kind: .notes, preset: .text("""
                Offer 1: BlackRock, Analyst, Aladdin Engineering (New York, NY)
                Start: July 2027, full time, hybrid 4 days in office at 50 Hudson Yards
                Base salary: $125,000
                Sign-on bonus: $15,000 (repayable if you leave within 12 months)
                Annual bonus target: 10% of base, discretionary, first payout pro-rated in Jan 2028
                Equity: none at the Analyst level. Employee stock purchase plan at 5% discount.
                401(k): 100% match on the first 8% after 1 year of service
                Relocation: $7,500 lump sum, taxed
                Benefits: medical, dental, vision from day one, 20 PTO days, 2 volunteer days
                Housing note from my own research: 1 bed in Jersey City or Long Island City roughly $3,200 to $3,600
                NY state plus city income tax on top of federal
                Offer expires: October 15
                """)),
            right: .init(kind: .notes, preset: .text("""
                Offer 2: Nuro Labs (Series B, about 140 people), Software Engineer I (Austin, TX)
                Start: June 2027, full time, hybrid 3 days at the Domain office
                Base salary: $118,000
                Sign-on bonus: $10,000, no clawback
                Annual bonus: none
                Equity: 12,000 ISOs, strike $3.10, 4 year vest with 1 year cliff, monthly after. Last preferred price $9.40 (Series B, March 2026). 409A FMV $3.10.
                401(k): 4% match, immediate
                Relocation: $5,000, grossed up
                Benefits: medical 100% paid for employee, dental and vision, unlimited PTO (team average they quoted is 18 days), $1,500 learning stipend
                Housing note: 1 bed near the Domain roughly $1,500 to $1,800
                No state income tax in Texas
                Offer expires: October 8, recruiter said a week extension is possible if I ask
                """)),
            instruction: "Side by side table: year 1 cash, 4 year expected value of equity at the last preferred price, take-home after rent and state tax, time off, risk. End with a verdict row."
        ),
        DemoScenario(
            id: "review-contradictions",
            title: "Fact check the op-ed",
            subtitle: "Wikipedia + op-ed → contradictions table",
            symbol: "newspaper",
            left: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/Electric_car")!)),
            right: .init(kind: .notes, preset: .text("""
                Op-ed draft: The electric car is a 30 year old idea that is finally winning

                Electric cars feel like a product of the last decade, and in a sense they are. The first electric car ever built was General Motors' EV1 in 1996, a two seat coupe that GM leased in California and Arizona and then famously crushed. Nothing like it had existed before, and the idea sat dormant until Tesla revived it.

                The modern era really begins with the Nissan Leaf, which launched in 2016 as the first mass market electric hatchback, and with the Tesla Model 3 a year later. In 2023 electric cars made up roughly 18% of new car sales worldwide, with China accounting for the majority of them. Norway is the outlier where most new cars sold are already electric.

                Critics still raise the same objections. Range anxiety is real, though a typical new EV now travels well over 200 miles on a charge. Charging is slow compared with a fuel stop, and unlike gas cars, electric cars have no way to recover energy when slowing down, so every stop light is wasted range. Even so, the running costs are lower and the tailpipe is gone.

                The electric car is not a fad. It is the default that the gasoline car briefly interrupted.
                """)),
            instruction: "Table of every claim in the op-ed that contradicts the article: the claim, what the article says, and the corrected sentence."
        ),
        DemoScenario(
            id: "review-merge",
            title: "Merge two drafts",
            subtitle: "Version A + Version B → merged paragraph",
            symbol: "text.append",
            left: .init(kind: .notes, preset: .text("""
                Version A (mine, Tuesday)

                Fuse is a small iOS app for folding phones that treats the two halves of the screen as two inputs to one question. You put a web page, a note, a photo, a document, a calendar, or whatever you just copied on each side, type one line about what you want, and the app reads both at once. The result shows up on the cover display first as a short card, and expands into a full view when you unfold the phone. Nothing is uploaded until you press the button, and the app never keeps a copy of either screen after the result is produced. It works on Surface Duo, Galaxy Z Fold, and Pixel Fold sized devices, and on a regular iPhone it falls back to a split view.
                """)),
            right: .init(kind: .notes, preset: .text("""
                Version B (Priya, Wednesday, from the App Store draft)

                Fuse turns a folding phone into a two input assistant. Open anything on the left, anything on the right, and ask one question about both. Supported surfaces today: web pages, Apple Notes text, photos, PDF and text documents, your calendar, and the clipboard. Results arrive as a compact card on the outer screen and unfold into a full result with tables, diffs, code, or images inside. Your screens are sent only when you tap Fuse, are processed once, and are discarded immediately afterward. Free accounts get three fuses a day; Fuse Pro removes the limit. Requires iOS 26 or later. On non folding iPhones the app runs in a stacked layout.
                """)),
            instruction: "Merge these into one paragraph in markdown that keeps every fact from both, drops the repeats, and reads in one voice. Below it, list anything the two versions disagree on."
        ),
        DemoScenario(
            id: "review-listing-reality",
            title: "Listing vs reality",
            subtitle: "Listing + tour notes → claims table",
            symbol: "key",
            left: .init(kind: .notes, preset: .text("""
                Listing: 1BR at Lyra Apartments, Unit 305, $1,425/month
                Posted on Zillow, 14 photos

                "Bright, newly renovated one bedroom with quartz counters, stainless appliances, in-unit washer/dryer, walk-in closet, and a private balcony overlooking the courtyard. Hardwood floors throughout. Central AC, new in 2024. Assigned covered parking included. Water and trash included. Quiet building, professional and grad student residents. Gym and pool on site. Walking distance to campus (0.6 mi). Cats and small dogs welcome. Available August 1. Deposit $500. Ask about our no-fee move-in."
                """)),
            right: .init(kind: .notes, preset: .text("""
                Tour notes, Lyra 305, Saturday 11 a.m. with Kelsey (leasing)

                - Counters are quartz, real. Appliances stainless but the dishwasher has a rust line and Kelsey said "we'd replace it if it breaks".
                - Washer/dryer: stacked unit in a closet, works. Fine.
                - "Walk-in closet" is a reach-in closet with a bifold door, about 5 ft wide.
                - Balcony faces the parking lot and the dumpster enclosure, not the courtyard. Courtyard units are 310 to 318 and are $1,575.
                - Floors are laminate in the living room, carpet in the bedroom. Not hardwood anywhere.
                - AC: wall thermostat, unit on the roof. Kelsey did not know the install year. Vents were dusty.
                - Parking: covered spots are $60/month extra, uncovered is included.
                - Water and trash included but there is a $45/month "utility admin fee" on every lease.
                - Gym is two treadmills and a rack, one treadmill out of order. Pool closed for resurfacing until "sometime in September".
                - Measured on my phone: 0.9 mi to Turlington by the walking route, 0.6 is the straight line.
                - Dogs: $300 fee plus $40/month pet rent, breed list applies.
                - No-fee move-in requires a 15 month lease.
                - Hallway smelled like weed on the 3rd floor at 11 a.m.
                """)),
            instruction: "Table: each claim in the listing, what I actually saw, and a verdict of true, misleading, or false. End with the real monthly cost."
        ),
        DemoScenario(
            id: "review-error-code",
            title: "Decode the error",
            subtitle: "Error code + manual → fix checklist",
            symbol: "wrench.and.screwdriver",
            left: .init(kind: .notes, preset: .text("""
                Bosch E24 on the dishwasher display

                Model: Bosch SHXM63WS5N (300 series), bought 2022, out of warranty
                What happened: ran the Auto cycle after dinner, it stopped after about 20 minutes with E24 blinking and a beep. Some water sitting in the bottom, maybe an inch. Pressed Start again, same thing after 2 minutes.
                What I already tried: pulled the bottom rack, took out the filter cylinder and rinsed it, there was some rice in it. Put it back. Ran Rinse, still E24.
                The sink disposal is new, plumber installed it last week.
                Drain hose goes under the sink and loops up to the disposal inlet.
                I do not want to pay $150 for a service visit if this is something I can fix tonight.
                """)),
            right: .init(kind: .document, preset: .text("""
                Bosch Dishwasher, Use and Care Manual, Section 9: Fault codes and self help
                Work through the checks for your code before calling service. Switch the appliance off first.

                Code | Meaning | Checks
                E15 | Water in the base pan, AquaStop tripped | Tilt the appliance to drain the pan. If it recurs, call service.
                E22 | Filter blocked | Clean the filter system (6.2). Check the pump cover is locked.
                E24 | Appliance does not drain: hose blocked or kinked, or water cannot exit | 1. Check the drain hose is not kinked, trapped, or crushed behind the appliance. 2. Where the hose connects to a waste disposer, confirm the knock-out plug in the disposer inlet has been removed (new disposers ship with the plug in place). 3. Clean the filter (6.2) and the drain pump (6.3): twist off the pump cover and check the impeller for foreign objects. 4. Ensure the drain hose high loop is at least 20 inches above the floor. 5. Run the Rinse program to test.
                E25 | Drain pump blocked or pump cover loose | Clean the drain pump (6.3), press the cover until it clicks.
                E09 | Heating element fault | Call service.
                If the code persists after all checks, note the E-Nr from the door edge and contact Bosch Support.
                """)),
            instruction: "Checklist of what to do tonight, in order, skipping what I already tried. Flag the most likely cause first given the new disposal."
        ),
    ]
}
