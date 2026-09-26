# Fuse — use cases

What a fold can do today, ranked, plus five demo scenarios that run on the current surfaces (`Fuse/Surfaces/*.swift`) and the current router prompt (`Fuse/Engine/Prompts.swift`).

Already demoed (`Fuse/App/DemoScenarios.swift`) and excluded from the ranking: theme park + map → itinerary, conference email + calendar → event, practice test + answers → grade, job posting + resume → cover email, contract + policy → redline, calendar + map → route my day, article + wrong-facts note → contradictions, notes + article → pitch slides, photo + reference → edited image.

## 1. Relationship classes

Every idea reduces to one of these. The prompt's catalogue already covers the first six. The last three showed up repeatedly in the panel list and are worth one line each in `Prompts.system`.

| Class | Left + right | Artifact | Ideas that fit | Prompt status |
|---|---|---|---|---|
| Thing + Place → Plan | a page, event or document about something; where you are or where it is | itinerary | theme park + map; airport PDF + hotel pin; Rain Re-Plan | named |
| Thing + Time → Commitment | something that implies a when; your real calendar | event | conference email + calendar; Slot Finder; Group Chat, One Slot; Last Train Home; Business Card to Coffee | named |
| Reference + Draft → Correction | a source of truth; something that should agree with it | diff, grade, table (contradictions) | contract + policy; test + answers; article + blog draft; Recipe Redline | named |
| Two-of-a-kind → Verdict | two things of the same type | table, grade | Comparison That Grows; Listing vs Reality; Apartment Scorecard | named |
| Material + Intent → Artifact | raw material; what you want made from it | slides, email, code, checklist, markdown | notes + article → slides; Tent-Mode Pitch; Bedtime Story; Close Phone, Send Recap | named |
| Subject + Style → Image | a photo; a visual reference | image_edit | photo + reference | named |
| Rule + Situation → Ruling (new) | a rulebook (sign, lease, manual, newsletter, schedule); your specific case (calendar, text, error code, photo) | event, email, checklist | Parking Sign vs Calendar; Reply With the Lease; Landlord Repair Email; Appliance Error Fixer; School Newsletter; Who Drives When | not named. Add: "When one screen is a rule set, quote the exact rule that applies and say why the others do not." |
| Amounts + Allocation → Ledger (new) | prices with no names; names with no prices | table | Split the Check | not named. Add: "When splitting a total, rows must sum to the source total; say so in the note." |
| Result + Change → Re-plan (new, chaining) | a kept result; something that changed or was added | the same artifact type, revised | Comparison That Grows (third column); Rain Re-Plan; Apartment Scorecard → side-by-side | not named. Today a kept result reaches the model as a screenshot plus text; see section 4. |

## 2. Ranked ideas

Panel averages, three judges. Duplicates merged: the three receipt entries into Split the Check; the three parking entries into Parking Sign vs Calendar (the "fold means I'm parked" framing the panel preferred). Airport Leave-By Plan (5.83) dropped: the map pin duplicates GPS and the drive leg is a guess until MKDirections is wired in.

| # | Idea (avg) | Left | Right | Artifact | Why both screens | Demo beat | Feasible now |
|---|---|---|---|---|---|---|---|
| 1 | Comparison That Grows (7.5) | Browser: product page A | Browser: product page B | table | The result stays on one half while the other half keeps browsing; each fold appends a column | Fold: two columns. Keep the table, open a third page, fold: a column grows and the verdict flips | Yes |
| 2 | Close Phone, Send Recap (7.5) | Calendar: the meeting event (tabletop pose, upright half) | Notes: scrappy notes typed during the meeting (flat half) | email | Who and when from the calendar, what from the notes; closing the phone is "meeting over" | Three typed lines, snap shut, cover reads "Recap to 4 attendees — ready to send" | Yes; attendee emails are not yet in calendar metadata |
| 3 | Slot Finder (7.33) | Photo: screenshot of a thread with five free-text constraints | Calendar: real next 7 days | event | Their constraints on one side, yours on the other; the answer is the intersection | Five contradictory replies collapse into one invite; the notes say who killed which slot | Yes |
| 4 | Split the Check (7.17) | Photo: camera shot of the itemized receipt | Notes: who had what, tip percent | table | The receipt has prices without names; the note has names without prices; tax and tip need both | Fold, slide the closed phone across the table; the cover shows "Priya owes $27.40" | Yes; the rows must reconcile to the printed total or the demo fails on camera |
| 5 | Group Chat, One Slot (6.67) | Photo: screenshot of a "Dinner??" group thread | Calendar: real next 7 days | event | The chat holds everyone's constraints and the neighborhood; the calendar holds yours | Event tile on the cover reading "works for all 5"; chain: "write the reply" | Yes; keep the thread short enough to fit one screenshot |
| 6 | Recipe Redline (6.5) | Browser: a recipe page | Notes: headcount, diets, dislikes, equipment | diff | Exact quantities on one side, exact constraints on the other; cooks want the changes, not a rewrite | Red strikethrough on "heavy cream", green "coconut milk", tagged "Jules is vegan" | Yes |
| 7 | Parking Sign vs Calendar (6.5) | Photo: a stack of parking signs | Calendar: today's real events | event | The sign says when you cannot be here; the calendar says how long you will be gone | Cover reads "Move car by 3:20 PM" as you lock the phone and walk away | Yes; day-of-week and "2nd Tuesday" arithmetic is a known failure mode, rehearse the exact sign |
| 8 | Bedtime Story From Fridge Art (6.5) | Photo: a kid's crayon drawing | Notes: child's name, age, pet, this week's fear, length | markdown | The drawing gives the characters; the note gives the child and the length | Cover shows the title; page one names the sun-with-a-face the audience can see | Yes |
| 9 | Appliance Error Fixer (6.5) | Photo: "E24" on the dishwasher panel | Files: the owner's manual | checklist | The error is on the machine; its meaning is on page 58 of the manual | Closed phone propped under the sink shows "Step 1: drain pump filter, p. 31" | Yes, with a caveat: the fault table sits past the 8k clip unless clipping is keyword-aware |
| 10 | Reply With the Lease (6.5) | Photo: screenshot of the landlord's text | Files: the signed lease | email | The text is the demand; the lease is the leverage | The email quotes "not less than sixty (60) days" with the section number | Yes; keep the lease under the 8k clip or clip by keyword |
| 11 | Grandma's Card, Saturday's Party (6.33) | Photo: handwritten recipe card | Calendar: Saturday dinner for 8, plus a 4:30 haircut | checklist | The card has yields and durations; the calendar has serve time, headcount and the conflict | Cover reads "Start sauce at 2:45"; the haircut collision is flagged | Yes |
| 12 | School Newsletter, Your Week (6.33) | Files: two-page school newsletter | Calendar: the family's next 7 days | checklist | The newsletter has the dates; the calendar has the collisions | Two pages fold into eight checkbox lines, two flagged with the conflicting event | Yes; a batch events artifact would land every date in Calendar |
| 13 | Apartment Scorecard (6.17) | Browser: a listing | Notes: must-haves and nice-to-haves | grade | Dealbreakers hide in listing fine print; the criteria live in your notes | Score ring fills to 7/10, a red FAIL row quotes "cats only"; chain a second listing into a table | Yes; listing sites may block WKWebView text, and "25 min to campus" cannot be checked from the page |
| 14 | Landlord Repair Email (6.17) | Photo: the water stain or the 84°F thermostat | Files: the lease | email | The photo is the evidence; the lease is the leverage | The email quotes the repair clause and describes the stain from the photo; tap Send | Yes; same clip caveat as #10 |
| 15 | Listing vs Reality (6.17) | Browser: the listing you toured | Photo: a picture from inside the unit | table | Claim on one side, evidence on the other; folding holds them together | Row: "gleaming hardwood" / carpet visible / False | Yes; keep every claim to what is literally in frame |
| 16 | Last Train Home (6.17) | Browser: transit agency late-night timetable | Calendar: tonight's show | event | The end time and the last departure come from different sources; the leave-by moment is where they overlap | Cover: "Leave by 11:20 PM or it is a $45 ride" | Partly; many timetables render in JS widgets with no innerText |
| 17 | Rain Re-Plan (6.0) | Itinerary result kept from the previous fuse | Browser: hourly forecast | itinerary | Only a foldable holds the finished plan while the other half shows what changed | Stops visibly reorder; the 2–5 PM window fills with indoor rides | Yes, as an encore to the theme-park demo |
| 18 | Tent-Mode Pitch (6.0) | Photo: the whiteboard | Files: a one-page brief | slides | Fusing needs both inputs; presenting needs the hinge: slide out, notes in | The phone stands as a tent on the judges' table; Back Tap advances both faces | No; needs a SlidesTentView keyed to the hinge angle |
| 19 | Business Card to Coffee (6.0) | Photo: the business card | Calendar: real next 7 days | email | The card says who; the calendar says when | Email addressed from the card with two real open slots; chain "hold Tue 2pm" into an event | Yes |
| 20 | Who Drives When (5.83) | Files: kids' activity schedule | Calendar: your next 7 days | table | A static schedule against a live calendar; the fuse finds the collisions | A red conflict badge on Thursday naming the real event; chain the drives into events | Yes |

## 3. Five new demo scenarios (feasible today)

Ground rules used here:

- Browser content is Wikipedia or Wikibooks: stable innerText, no bot walls, no JS-only widgets. All five URLs were checked and return 200.
- Files content is seeded with `.text(...)`. `DocumentSurfaceModel.apply` only imports file URLs (`copyToTemporary` copies with `FileManager`, which cannot read https), so `.document(https://…)` would fail.
- Calendar uses the sample week (`.text("sample")`). The sample week is relative to today, so scenarios that mention weekdays assume the demo runs on a Saturday (Sep 26: Mon–Fri are sample days +2…+6). On another day the model still resolves the weekdays against the dates it is given; only which conflict fires changes.
- Every text below is under the 8k clip, so nothing the result needs gets trimmed.

### 3.1 compare-folds — Comparison That Grows

Browser + Browser → table. Two foldables on a foldable. The prompt's catalogue already maps "two products → comparison" to `table`.

Expected result: columns Spec / Galaxy Z Fold 6 / Pixel 9 Pro Fold; rows for launch price, weight, inner display, cover display, battery, hinge and crease, and a verdict row. Both pages carry these facts in the infobox text.

Chain: keep the table on the left, load `https://en.wikipedia.org/wiki/OnePlus_Open` on the right, fold with "Add this one to the comparison." The table comes back with a third column and a revised verdict.

```swift
DemoScenario(
    id: "compare-folds",
    title: "Comparison that grows",
    subtitle: "Two product pages → comparison table",
    symbol: "tablecells",
    left: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/Samsung_Galaxy_Z_Fold_6")!)),
    right: .init(kind: .web, preset: .url(URL(string: "https://en.wikipedia.org/wiki/Pixel_9_Pro_Fold")!)),
    instruction: "Compare them: launch price, weight, inner and cover displays, battery, hinge and crease. End with a verdict row."
)
```

### 3.2 recap — Close Phone, Send Recap

Calendar + Notes → email. Tabletop pose: the sample week stands upright on the top half, the notes lie flat on the bottom half. The notes reference the sample week's "Product sync" event.

Expected result: an email to Sam, Priya and Dev with Decisions / Action items (owner, due) / Open questions, and a proposed next sync taken from a real gap in the sample week (the model has every event with times). The `to` field is filled from the addresses in the notes; once attendee emails are in calendar metadata, the notes can drop them.

```swift
DemoScenario(
    id: "recap",
    title: "Close phone, send recap",
    subtitle: "Calendar + meeting notes → recap email",
    symbol: "envelope.badge",
    left: .init(kind: .calendar, preset: .text("sample")),
    right: .init(kind: .notes, preset: .text("""
        Product sync — notes (typed during the call)

        people: me, Sam (sam@fusehq.dev), Priya (priya@fusehq.dev), Dev (dev@fusehq.dev)
        decided: ship dark mode Thursday. cover-display card first, full result view after
        Sam owns QA on the hinge-angle thresholds — needs the Duo simulator build by Wed
        Priya blocked on icons, waiting on the SF Symbols set from design
        Dev: RevenueCat paywall copy is done, wants my review before it ships
        open: cap free fuses at 3/day or 5/day? nobody agreed
        open: Supabase feed public by default or opt-in?
        next sync?? find a time, everyone was double-booked today
        """)),
    instruction: "Recap this to everyone and propose the next sync from my free time."
)
```

### 3.3 slot-finder — Slot Finder

Clipboard + Calendar → event. The thread is pasted text rather than a screenshot, so nothing depends on OCR; the Photo variant (a real Slack screenshot) is a drop-in swap for the left half.

Expected result: one 30-minute event on Tuesday at 9:00 (Dev: Mon or Tue mornings; Sam: not Mon, Tue 9–12; Jordan: not Tue 10; Priya: before 11). With a Saturday demo day the sample week's Tuesday has only Gym 7:00–8:00, so 9:00–9:30 clears. The event notes walk the eliminations: Mon out (Sam), Fri out (Dev, Priya), Tue 10 out (Jordan), after 11 out (Priya). Attendees: Dev, Sam, Jordan, Priya, Maya.

```swift
DemoScenario(
    id: "slot-finder",
    title: "Slot finder",
    subtitle: "Pasted thread + calendar → one invite",
    symbol: "calendar.badge.checkmark",
    left: .init(kind: .clipboard, preset: .text("""
        #design — pasted from Slack

        Maya  9:02 AM
        can we do 30 min this week to lock the cover-display card? need everyone

        Dev  9:04 AM
        Mon or Tue work for me, mornings only

        Sam  9:05 AM
        not Mon, I'm travelling. Tue 9–12 is fine, otherwise Fri

        Jordan  9:11 AM
        anything but Tue at 10, that's my 1:1

        Priya  9:15 AM
        before 11 please, school pickup stuff after that all week

        Maya  9:16 AM
        ok someone pick a time
        """)),
    right: .init(kind: .calendar, preset: .text("sample")),
    instruction: "Find the one 30-minute slot that works for everyone and me."
)
```

### 3.4 recipe-redline — Recipe Redline

Browser + Notes → diff. The Wikibooks page lists servings (4), time (1 hour) and quantities (single cream, cilantro, chile), so every change has an exact original to strike through.

Expected result: original → revised → reason rows: cream → coconut cream (Jules, vegan); chicken split into chicken plus a second protein for Jules, seared in batches (one pot); chile reduced with a side of chile for the adults (kids); cilantro moved to a garnish bowl (Dad); quantities scaled 4 → 7; verdict on whether 5:00 to 7:00 is enough time.

Chain: keep the redline, put Notes "fridge: onions, garlic, canned tomatoes, rice, yogurt" on the other half, fold: a checklist of only what is missing.

```swift
DemoScenario(
    id: "recipe-redline",
    title: "Recipe redline",
    subtitle: "Recipe page + who's coming → redline",
    symbol: "fork.knife",
    left: .init(kind: .web, preset: .url(URL(string: "https://en.wikibooks.org/wiki/Cookbook:Chicken_Tikka_Masala")!)),
    right: .init(kind: .notes, preset: .text("""
        Sunday dinner, 7 people (recipe says 4)
        Jules — vegan
        Omar — gluten-free
        Dad — hates cilantro
        the kids (2) — nothing spicy
        only one big pot + the oven
        start cooking at 5, eat at 7
        """)),
    instruction: "Make it work for everyone on this list."
)
```

### 3.5 lease-reply — Reply With the Lease

Files + Clipboard → email. The lease is short enough to survive the clip in full, so every citation is checkable on the left half. The landlord's text arrives by Messages, which Section 22 says is not notice.

Expected result: a polite reply that cites §3 (rent fixed for the initial term), §14 (sixty days' written notice, no increase before Jul 31, 2027, then capped at 5%), and §22 (a text is not notice), states the earliest lawful effective date (Aug 1, 2027, with notice by Jun 1, 2027), and offers a counter (early renewal at a smaller increase). Cover display: "Rent can't rise before Aug 1, 2027 — reply ready."

```swift
DemoScenario(
    id: "lease-reply",
    title: "Reply with the lease",
    subtitle: "Lease + landlord's text → cited reply",
    symbol: "doc.text.magnifyingglass",
    left: .init(kind: .document, preset: .text("""
        RESIDENTIAL LEASE AGREEMENT
        Premises: 1427 NW 3rd Ave, Apt 2B, Gainesville, FL 32603
        Landlord: Alachua Ridge Properties LLC ("Landlord"). Tenant: Maya Chen ("Tenant").
        Term: August 1, 2026 through July 31, 2027 (the "Initial Term").
        Excerpt: Sections 3, 4, 14, 15, 22

        3. Rent. Tenant shall pay $1,450.00 per month, due on the 1st. Rent is fixed for the Initial Term and shall not be increased during the Initial Term.

        4. Renewal. Not less than sixty (60) days before the end of the Initial Term, Landlord shall deliver written notice of any proposed renewal terms, including any change in rent. If Tenant does not accept in writing within fifteen (15) days of receiving the notice, this Lease converts to month-to-month at the then-current rent on the same terms.

        14. Rent Adjustment. Any increase in rent requires not less than sixty (60) days' written notice delivered per Section 22, and no increase may take effect before the end of the Initial Term. During any month-to-month period there shall be no more than one increase in any twelve (12) month period, not to exceed five percent (5%) of the then-current rent.

        15. Repairs. Landlord shall complete repairs affecting habitability within seven (7) days of written notice, and all other repairs within thirty (30) days.

        22. Notices. All notices under this Lease must be in writing and delivered by hand, certified mail, or email to the addresses below. Text messages do not constitute notice under this Lease.
        Landlord: leasing@alachuaridge.com · 2201 NW 13th St, Suite 400, Gainesville, FL 32609
        Tenant: at the Premises · maya.chen.dev@gmail.com
        """)),
    right: .init(kind: .clipboard, preset: .text("""
        Pasted from Messages — Rick (landlord), today 4:12 PM

        Hey Maya, heads up: rent is going to $1,700 starting Nov 1. Market's up a lot around campus. Let me know you're good with it. Thanks
        """)),
    instruction: "Reply politely and cite the lease."
)
```

## 4. After the hackathon

Artifact types, in order of how many ranked ideas they unblock:

- `events` (batch): a newsletter, a kids' schedule or a thread → every date lands in Calendar in one tap (#5, #12, #20).
- `message`: a short reply with recipients, for iMessage, Slack or WhatsApp. Half the ranked ideas end in a text, not an email (#5, #10, #19).
- `reminder`: a Reminders entry with an alert and an optional location trigger. Better than an event for "move the car by 3:20" (#7).
- `ledger`: per-person rows whose amounts must sum to a source total, with pay links (#4).
- `timeline`: a checklist whose items carry times, scheduled backward from an anchor (#11, Airport Leave-By).
- `contact`: a business card → Contacts (#19).

Surfaces:

- Result: make a kept result a first-class surface that re-injects its JSON, not a screenshot plus text, so chaining (#1, #13, #17) edits the artifact instead of re-deriving it.
- Thread paste with sender and time parsing: the clipboard already takes text; splitting it into speaker/time makes #3 and #5 text inputs instead of screenshots.
- Weather for the map pin: an hourly forecast in map metadata makes #17 work without a browser tab.
- Contacts: attendee emails for #2 and #19.
- Live camera: a continuous viewfinder, so a fold captures the frame without a shutter press first (#4, #7, #9).

Plumbing, small and high value:

- Keyword-aware clip in `DocumentSurfaceModel`: keep the pages that mention the instruction's nouns, then fill to 8k. Fixes #9, #10, #14.
- Attendee emails in `CalendarSurfaceModel.capture()` metadata. Fixes #2.
- MKDirections drive time from the pin to a named destination in `MapSurfaceModel` metadata. Fixes Airport Leave-By.
- `SlidesTentView` keyed to the hinge angle. Makes #18 real.
- One prompt line: two document-like photos (a receipt and a chat screenshot) are documents, not an `image_edit` pair.

## 5. More ideas (not in the panel list)

All feasible with today's surfaces unless noted.

- Sketch to SwiftUI: Photo of a hand-drawn screen + Files (`.text` of the current view) → code. The catalogue allows it; the judges write SwiftUI.
- Red build: Photo of an Xcode error + Files (the source file) → code patch.
- Textbook page to quiz: Photo of the page + Notes "exam Friday, I mix up torque and angular momentum" → quiz. No demo uses `quiz` yet.
- Order what you can eat: Photo of the menu + Notes with allergies → table (dish, safe, ask the server).
- Flyer to calendar: Photo of a concert or club flyer + Calendar → event with the real conflict. The cheapest reliable photo + calendar beat.
- Price match: Browser showing the lower price + Clipboard with the order confirmation → email requesting the match.
- Pack for the week: Calendar (the sample week has the MCO → SFO flight with "Terminal C" and the YC demo with "Bring the Duo + charger") + Browser `https://en.wikipedia.org/wiki/Climate_of_San_Francisco` → checklist. Every line traceable to an event note or the page.
- Step 14 vs my shelf: Files (the furniture manual page as text) + Photo of what you built → checklist of what is wrong.
- Sign in another language: Photo of a menu or sign abroad + Notes "vegetarian, shellfish allergy" → markdown translation filtered by the constraints.
- What did I change: Notes (draft v1) + Notes (draft v2) → diff. Trivial and always works; good filler for a live Q&A.
