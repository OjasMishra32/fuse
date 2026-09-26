import Foundation
import UIKit

// MARK: - Make scenarios
//
// Material + intent on one screen, artifact on the other. Every scenario pairs some
// raw material (notes, a page, a thread, a photo) with a second screen that says
// what to do with it, and the result is a thing you can hand to someone: a quiz,
// an email, a table, a story, an image.

extension DemoScenario {
    static let make: [DemoScenario] = [
        DemoScenario(
            id: "make-quiz",
            title: "Quiz from notes",
            subtitle: "Lecture notes + outline → 8-question quiz",
            symbol: "questionmark.circle",
            left: .init(kind: .notes, preset: .text("""
                BSC2010 lecture 14, cellular respiration (my notes, messy)

                glycolysis: cytoplasm, glucose (6C) -> 2 pyruvate (3C). net 2 ATP, 2 NADH. no O2 needed.
                pyruvate oxidation: in mitochondrial matrix, pyruvate -> acetyl-CoA, loses CO2, makes NADH
                citric acid cycle (Krebs): matrix. per glucose: 2 turns, 6 NADH, 2 FADH2, 2 ATP (GTP), 4 CO2
                oxidative phosphorylation: inner membrane. ETC pumps H+ into intermembrane space
                -> proton gradient -> ATP synthase spins -> ATP. chemiosmosis. O2 is the final electron acceptor, makes water
                total ~30-32 ATP per glucose (prof said the old textbook number 36-38 is wrong)
                NADH ~2.5 ATP, FADH2 ~1.5 ATP
                fermentation: no O2. regenerates NAD+ so glycolysis can keep going. lactic acid (muscle) vs alcohol (yeast). only the 2 ATP from glycolysis
                cyanide blocks complex IV -> no ATP -> why it kills
                brown fat: uncoupling protein lets H+ leak, makes heat not ATP
                exam Q hint: "where does each stage happen" always shows up
                """)),
            right: .init(kind: .notes, preset: .text("""
                BSC2010 course outline, unit 3 (energy)

                Week 7: enzymes and free energy
                Week 8: cellular respiration
                  - glycolysis, pyruvate oxidation, citric acid cycle, oxidative phosphorylation
                  - location of each stage, inputs and outputs per stage
                  - chemiosmosis and ATP synthase
                  - fermentation vs aerobic respiration, ATP yield comparison
                  - applications: poisons that block the ETC, thermogenesis
                Week 9: photosynthesis (light reactions, Calvin cycle)

                Exam 3 covers weeks 7 to 9. Format: 8 multiple choice, 4 options each, one short answer.
                Learning objectives for week 8: trace a glucose molecule through all four stages; explain why oxygen is required; compare ATP yields; predict what happens when a step is blocked.
                """)),
            instruction: "Write an 8-question practice quiz on the week 8 material, in the exam format from the outline, with an answer key at the end."
        ),
        DemoScenario(
            id: "make-reply",
            title: "Reply from notes",
            subtitle: "Meeting notes + email thread → reply",
            symbol: "envelope",
            left: .init(kind: .notes, preset: .text("""
                Vendor call with Northgate Print, Tue 2:15 PM (my notes)

                on the call: me, Dana (their account lead), Marco (their production guy)
                banners: they can do 6 by 3 ft vinyl, matte, grommets every 2 ft. $84 each for 10, $71 each if we go to 20
                turnaround: 5 business days from proof approval, rush is 3 days for +25%
                proof: they send a PDF proof within 24 hrs of getting final art. one free revision, then $40 each
                art specs: 150 dpi at full size, CMYK, 0.5 inch bleed, PDF or AI
                shipping: free to campus if under 25 lb, otherwise $35 flat
                Marco says the blue we sent will print darker than it looks on screen, suggested we bump it or send a Pantone
                Dana asked for a PO number before they start
                we said: go with 20, standard turnaround, we'll send Pantone 2935 and the PO by Thursday
                event is Oct 18 so we need them in hand by Oct 14 latest
                """)),
            right: .init(kind: .clipboard, preset: .text("""
                Pasted from Mail

                From: Dana Whitfield <dana@northgateprint.com>
                To: Ojasva Mishra <ojasvamishra@ufl.edu>
                Subject: Re: Re: Career fair banners, quote and timeline
                Date: Wed, Sep 24, 2026 9:41 AM

                Hi Ojasva,

                Great talking yesterday. Just confirming what I have on my end so we can get this scheduled:
                - Quantity and finish
                - Which turnaround you want
                - Color: Marco flagged the blue again, do you have a Pantone or should we match to the file?
                - PO number so I can open the job

                Once I have those I'll get the proof over within a day of receiving final art.

                Thanks,
                Dana

                > On Sep 22, 2026, Ojasva Mishra wrote:
                > Hi Dana, could we hop on a quick call Tuesday afternoon to lock in the banner order for the Oct 18 career fair? We're deciding between 10 and 20.
                >
                > > On Sep 21, 2026, Dana Whitfield wrote:
                > > Hi Ojasva, thanks for reaching out. Attached is our quote for 6x3 vinyl banners at 10 and 20 units. Happy to walk through it on a call.
                """)),
            instruction: "Reply to Dana answering every item she listed, using what we agreed on the call, and ask her to confirm the delivery date."
        ),
        DemoScenario(
            id: "make-grandma",
            title: "Explain to grandma",
            subtitle: "CRISPR article + ask → 5 plain sentences",
            symbol: "text.book.closed",
            left: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/CRISPR")!)),
            right: .init(kind: .notes, preset: .text("""
                Grandma asked me what I'm working on in the lab and I said "CRISPR" and she said "the what"

                explain to my grandma, 5 sentences
                she's 81, was a middle school English teacher, sharp, but no science after high school
                she likes gardening and sewing, use one of those if it helps
                no jargon: no "Cas9", no "guide RNA", no "nuclease"
                she'll ask "is it dangerous" so the last sentence should be honest about that
                I want to read this to her on the phone tonight
                """)),
            instruction: "Write the explanation exactly as I'd read it aloud to her."
        ),
        DemoScenario(
            id: "make-prd",
            title: "Spec to PRD",
            subtitle: "Product page + sketch → PRD",
            symbol: "doc.plaintext",
            left: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/AirPods")!)),
            right: .init(kind: .notes, preset: .text("""
                Feature sketch: "Find my case" for our earbuds app (v2.3)

                problem: people lose the case, not the buds. support tickets: 31% of "lost device" tickets last quarter were case-only
                idea: case gets a tiny speaker + BLE beacon (hardware team says feasible for the next rev, ~$0.40 BOM)
                app side:
                  - map view showing last known location of case (from last phone connection)
                  - "play sound" button, only enabled when case is within BLE range
                  - if out of range, show last seen time + address, offer directions
                  - notification when you leave the case behind (phone moves >200m from case with buds connected)
                  - works for the case even if buds are inside it and charging
                non-goals for v2.3: network-based finding via other users' phones, lost mode lock
                constraints: battery drain on the case under 2%/day from the beacon. no location data leaves the device except to Maps for directions
                open q: should "left behind" alerts be on by default? privacy team wants opt-in
                success: case-only lost tickets down 50% within 2 releases
                ship target: March
                """)),
            instruction: "Turn this into a PRD in markdown: problem, goals, non-goals, user stories, requirements, and numbered acceptance criteria that QA can test. Use the product page for context on how the existing product works."
        ),
        DemoScenario(
            id: "make-method",
            title: "Explain the method",
            subtitle: "Paper abstract + ask → explanation",
            symbol: "flask",
            left: .init(kind: .notes, preset: .text("""
                Abstract (pasted from arXiv)

                Sparse Mixture-of-Experts with Learned Routing Temperature

                Mixture-of-Experts (MoE) layers scale model capacity by routing each token to a small subset of expert sub-networks, but standard top-k routing with a fixed softmax produces unstable expert utilization and requires auxiliary load-balancing losses that trade off quality for balance. We propose Learned Routing Temperature (LRT), in which each router learns a per-layer temperature parameter that is annealed from high (near-uniform routing) to low (sharp routing) during training, with the annealing schedule itself learned from the load-imbalance signal rather than fixed. Early in training, tokens are spread across experts almost uniformly, which gives every expert gradient signal and prevents the collapse where a few experts absorb most tokens. As experts specialize, the temperature drops and routing becomes decisive. We remove the auxiliary balancing loss entirely. On a 1.3B-parameter model with 8 experts and top-2 routing, LRT reaches the same validation loss as the baseline in 18% fewer steps and improves expert utilization entropy from 1.61 to 2.02 nats (max 2.08). We also show that LRT reduces the fraction of dropped tokens under capacity limits from 4.1% to 0.6%.
                """)),
            right: .init(kind: .notes, preset: .text("""
                explain the method

                I'm presenting this in reading group Thursday and I get the problem but not the method
                specifically:
                - what does the temperature actually do to the routing softmax, with a tiny numeric example (2 experts)
                - what does "annealed" mean here and why start high
                - how can the schedule be "learned from the load-imbalance signal", what's the signal, what's the gradient
                - why does this let them drop the aux loss
                - what's utilization entropy and why is 2.08 the max
                keep it to markdown with headers, maybe 400 words, I'll paste it into my slides notes
                assume the audience knows what MoE and top-k routing are
                """)),
            instruction: "Answer each of my questions in order, in markdown, using the abstract as the source."
        ),
        DemoScenario(
            id: "make-deescalate",
            title: "Calm it down",
            subtitle: "Heated Slack thread + intent → email",
            symbol: "bubble.left",
            left: .init(kind: .clipboard, preset: .text("""
                #proj-checkout, pasted from Slack

                Theo  4:47 PM
                the payments API change shipped without the migration and prod is throwing 500s on every guest checkout. who approved this

                Riya  4:49 PM
                I approved it. the migration was in the PR description as a follow-up, we agreed on that in standup Monday

                Theo  4:50 PM
                we absolutely did not agree to ship a breaking change with a "follow-up". that's not a plan that's a hope

                Riya  4:52 PM
                I have the standup notes. you said "fine, ship it, do the migration after." I'm not making this up

                Theo  4:53 PM
                I said that about the LOGGING change. not this. you're conflating two things

                Riya  4:55 PM
                ok so now it's my fault for not reading your mind. I've been on call for 3 nights, I rolled back 20 min ago, guest checkout is fine now. maybe check the dashboard before blowing up the channel

                Theo  4:56 PM
                I checked the dashboard. that's how I found out. because nobody told me

                Marcus  4:58 PM
                hey, can we take this to a call

                Theo  4:58 PM
                I'm done for today
                """)),
            right: .init(kind: .notes, preset: .text("""
                I'm Riya. I want to email Theo tonight before tomorrow's standup.

                what I actually want:
                - calm, keep the relationship. he's a good engineer and we have to work together for months
                - own the part that's mine: I should have pinged him directly when I saw the 500s, and "follow-up migration" was a bad plan even if he did say ok
                - NOT relitigate who said what in standup. drop it. doesn't matter
                - I'm exhausted and I snapped, the "read your mind" line was out of line
                - propose: 15 min tomorrow before standup, just us, and a rule going forward that schema changes ship with their migration in the same PR, no exceptions
                - keep it short, he won't read a wall of text
                - no corporate speak, no "I apologize if you felt"
                """)),
            instruction: "Write the email."
        ),
        DemoScenario(
            id: "make-split",
            title: "Split the bill",
            subtitle: "Receipt + who had what → table",
            symbol: "receipt",
            left: .init(kind: .notes, preset: .text("""
                THE COPPER PIG
                Table 12, server: Ana
                Sat Sep 20 2026, 8:52 PM

                1  Burrata and peaches          14.00
                1  Wings (dozen)               16.00
                1  Smash burger                 17.00
                1  Mushroom risotto             21.00
                1  Steak frites                 34.00
                1  Fish tacos (3)               18.00
                2  House red (glass)     2 x 11 22.00
                1  IPA pint                      8.00
                1  Lemonade                      4.00
                1  Sparkling water (bottle)      6.00
                1  Churros (share)              10.00

                Subtotal                       170.00
                Tax 7%                          11.90
                Total                          181.90

                Gratuity not included. Suggested: 18% 30.60 / 20% 34.00 / 22% 37.40
                """)),
            right: .init(kind: .notes, preset: .text("""
                who had what, Copper Pig

                me: steak frites, one glass of red
                Nina: mushroom risotto, the other glass of red
                Jake: smash burger, the IPA
                Priya: fish tacos, lemonade
                shared 4 ways: burrata, wings, churros, sparkling water
                tip 20%, and split the tax and tip proportional to what each person ate, not evenly
                Jake already put $40 on the card so show what everyone owes him
                round to the nearest cent
                """)),
            instruction: "Build the split as a table: one row per person with their items, subtotal, tax share, tip share, total, and what they owe Jake. Show the check math at the bottom."
        ),
        DemoScenario(
            id: "make-pairing",
            title: "Pick the wine",
            subtitle: "Wine list + tonight's dish → pairing",
            symbol: "wineglass",
            left: .init(kind: .notes, preset: .text("""
                Wine list, Lumen (photographed the menu, typed it up)

                WHITE
                Sancerre, Domaine Vacheron 2023, Loire            glass 16 / bottle 62
                Albariño, Pazo Señorans 2023, Rías Baixas         glass 13 / bottle 50
                Chablis 1er Cru, William Fèvre 2022               bottle 88
                Grüner Veltliner, Bründlmayer 2023, Kamptal       glass 12 / bottle 46
                Riesling Kabinett, Dönnhoff 2022, Nahe            glass 14 / bottle 54

                ROSE
                Bandol Rosé, Domaine Tempier 2023                 bottle 72

                RED
                Pinot Noir, Cristom 2022, Willamette Valley       glass 18 / bottle 70
                Barbera d'Alba, Vietti 2022                        glass 13 / bottle 48
                Chinon, Bernard Baudry 2022, Loire                glass 14 / bottle 52
                Rioja Reserva, La Rioja Alta 2018                  bottle 84
                Malbec, Catena 2022, Mendoza                       glass 12 / bottle 44
                Syrah, Jean-Louis Chave Selection 2021, Rhône      bottle 76
                """)),
            right: .init(kind: .notes, preset: .text("""
                tonight, 2 of us

                she's getting: pan-roasted halibut with brown butter, capers, lemon, and a fennel salad
                I'm getting: the duck breast with cherry gastrique and roasted beets
                we'd rather share one bottle than do glasses, budget around $60-70
                she doesn't like oaky/buttery whites. I don't like big tannic reds
                if there's no single bottle that works for both, a glass each is fine, tell me which
                also it's her birthday so if one of them is a little special say why
                """)),
            instruction: "Recommend the bottle, explain the pairing in plain language for both dishes, and give a backup plan."
        ),
        DemoScenario(
            id: "make-bedtime",
            title: "Bedtime story",
            subtitle: "Kid's drawing + kid facts → story",
            symbol: "moon.stars",
            left: .init(kind: .notes, preset: .text("""
                Leo's drawing tonight (describing it, he wants a story about it)

                a purple dragon with very short legs and huge wings, named "Pancake" (he named it)
                Pancake is standing on top of a lighthouse. the lighthouse is striped red and white
                there's a small boat in the water with three people in it: a girl with a yellow raincoat, a dog, and "the captain" who has a big mustache
                it's night, there's a moon with a face and it looks worried
                there's a storm on the right side of the page, scribbled black clouds and lightning
                the dragon is holding a giant flashlight (Leo says the lighthouse light broke)
                at the bottom he wrote "PANCAKE HELPS" in orange
                """)),
            right: .init(kind: .notes, preset: .text("""
                Leo facts

                age 5, turning 6 in November
                scared of thunder right now, so the storm should be a little scary and then not scary
                loves: pancakes (obviously), his dog Biscuit, being the helper, counting things
                doesn't like: stories where someone gets in trouble, or where the animal gets hurt
                likes when the story has a part he can say along with me, like a repeated line
                bedtime story should be about 4 minutes read aloud, so roughly 500 words
                end with everyone asleep, that helps him settle
                his little sister is Mae, she's 2, if she's in it he'll love that
                """)),
            instruction: "Write the 4-minute bedtime story about his drawing, in markdown, with a repeated line he can say along."
        ),
        DemoScenario(
            id: "make-repair",
            title: "Repair request",
            subtitle: "Photo description + lease clause → email",
            symbol: "hammer",
            left: .init(kind: .notes, preset: .text("""
                what I'm looking at (photos attached separately)

                bathroom ceiling, directly above the shower: brown water stain about the size of a dinner plate, paint bubbling in the middle, and a small crack where a drip forms
                the drip is slow, maybe one drop every 30 seconds when the upstairs neighbor showers (they're in 3B, we're in 2B)
                started as a faint spot around Sept 12, got noticeably bigger this week, first actual drip was last night Sept 24
                there's a faint musty smell now in the bathroom
                I put a bucket under it
                I texted Rick (the landlord) on Sept 15 with a photo and he said "I'll take a look", nobody came
                I want this in writing now because the lease says text doesn't count as notice
                I'm not trying to be hostile, just want it fixed before it turns into mold
                available for entry any weekday after 3 PM or all day Saturday
                """)),
            right: .init(kind: .document, preset: .text("""
                RESIDENTIAL LEASE AGREEMENT
                Premises: 1427 NW 3rd Ave, Apt 2B, Gainesville, FL 32603
                Landlord: Alachua Ridge Properties LLC ("Landlord"). Tenant: Maya Chen ("Tenant").
                Excerpt: Sections 15, 16, 22

                15. Repairs. Landlord shall complete repairs affecting habitability, including but not limited to water intrusion, plumbing leaks, mold, heating, and electrical hazards, within seven (7) days of written notice. All other repairs shall be completed within thirty (30) days of written notice. Tenant shall promptly notify Landlord in writing of any condition requiring repair. If Landlord fails to complete a habitability repair within the period above, Tenant may pursue remedies available under Florida Statutes section 83.60 after providing the notice required therein.

                16. Entry. Landlord may enter the Premises to make repairs upon not less than twenty-four (24) hours' notice to Tenant, at reasonable times, except in an emergency.

                22. Notices. All notices under this Lease must be in writing and delivered by hand, certified mail, or email to the addresses below. Text messages do not constitute notice under this Lease.
                Landlord: leasing@alachuaridge.com; 2201 NW 13th St, Suite 400, Gainesville, FL 32609
                Tenant: at the Premises; maya.chen.dev@gmail.com
                """)),
            instruction: "Write the repair request email to the landlord as Maya. Describe the problem, cite the lease, give my availability for entry, and make it count as written notice."
        ),
        DemoScenario(
            id: "make-thankyou",
            title: "Thank-you notes",
            subtitle: "Gift list + person facts → notes",
            symbol: "gift",
            left: .init(kind: .notes, preset: .text("""
                Graduation party gifts (May 9), still owe thank-yous, ugh

                1. Aunt Rosa and Uncle Manny: $200 check + a card that said "for your first real apartment"
                2. Grandpa Joe: his old Seiko watch, the one he wore to work for 30 years. he cried a little
                3. Mrs. Patel (next door): a plant (pothos) in a blue pot, and a note saying it's impossible to kill
                4. Coach Daniels: a book, "Shoe Dog", with a note inside: "you never quit on the field, don't start now"
                5. The Nguyens (Priya's family): a Le Creuset dutch oven, red, way too generous
                6. Sam and Dev (roommates): a framed photo of the four of us from the camping trip, and a gift card to the coffee place
                """)),
            right: .init(kind: .notes, preset: .text("""
                things to mention per person

                Rosa and Manny: they drove 4 hours to come. Manny's knee surgery is in June, ask about it. Rosa always says "don't be a stranger" so use that
                Grandpa Joe: he taught me to change a tire in that watch. I'm wearing it to my first day at work Aug 3. handwritten, he doesn't do email
                Mrs. Patel: she watched me grow up, literally, since I was 4. she gave me the plant because I told her my dorm room had no windows. the new apartment has a big window
                Coach Daniels: I almost quit junior year and he didn't let me. keep it short and not sappy, he'd hate that
                The Nguyens: Priya's parents, they treat me like family. I want to cook them dinner in the dutch oven when they visit in August. Mrs. Nguyen's pho is what I'll try to make
                Sam and Dev: the camping trip was the one where the tent flooded. these can be funny, they're my roommates. we're all moving out May 30

                tone: warm, specific, sounds like me (I'm 22, not formal). each one 4-6 sentences. no "I hope this finds you well"
                """)),
            instruction: "Write all six thank-you notes in markdown, one section each, ready to copy onto cards."
        ),
        DemoScenario(
            id: "make-portrait-world",
            title: "Into the painting",
            subtitle: "Portrait + painting → one new image",
            symbol: "photo.on.rectangle.angled",
            left: .init(kind: .photo, preset: .image(UIImage(named: "SamplePortrait") ?? UIImage())),
            right: .init(kind: .photo, preset: .image(UIImage(named: "SampleStyle") ?? UIImage())),
            instruction: "Put the person into the painting's world as a single new image."
        ),
    ]
}
