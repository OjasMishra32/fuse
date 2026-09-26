# Fuse

**Tagline:** Put one thing on each screen. Fold the phone. The hinge is not navigation. It is the command.

## Inspiration

Every foldable app we could find uses the second screen for one of two things: a bigger canvas, or two apps sitting next to each other. The hinge itself, the one part of the device that is new, is treated as a layout event. It tells the app to re-flow.

We wanted the fold to mean something. When you close a laptop you are saying "I'm done." When you close a book you are marking a place. On the Duo you have two live things in your hands and a physical motion that brings them together. It seemed obvious that the motion should do the combining.

iOS 27.1 is the first time Apple has given developers the hinge angle continuously through `onHingeChange`. That made a fold you can feel, with an animation that follows your hand, possible for the first time on an iPhone.

## What it does

Each half of the open Duo hosts a live surface: a web page, a map pin, a note, a photo, a PDF, your calendar, or the clipboard. You put one thing on each side and fold the phone closed.

As the hinge passes about 165°, both panes begin melting toward the seam, driven directly by the angle. At the closed state Fuse captures both surfaces (text, pixels, coordinates, real calendar times) and sends them to OpenAI with one instruction: find the relationship between these two things and produce the single most useful result. The result renders on the cover display as a structured artifact, then lays out across both screens when you reopen.

There is no menu of features. The pairing is the feature:

- Theme park article + map pin → a one-day itinerary with times and coordinates
- Conference email + your calendar → an event, with the conflicts named
- Practice test with answer key + your answers → a grade report with weak spots
- Job posting + resume → a cover email that quotes both
- Vendor contract + procurement policy → a redline with reasons
- Your calendar + a pin → your day reordered geographically, with leave-by times
- Wikipedia article + blog draft → a contradictions table
- Messy notes + a background article → a six-slide pitch
- Photo + visual reference → an edited photo

Every result carries follow-ups ("Make a practice test on my weak spots") that re-fuse the same two screens with a new instruction, so one fold becomes a conversation.

If you cannot fold, you can pinch the two halves together, hold the core at the seam, hold to talk and speak an instruction, or trigger Fuse from Back Tap, the Action Button, or Siri through App Intents.

## How we built it

SwiftUI, Swift 5, `@Observable` throughout. One state machine (`AppModel`) with three phases: compose, fusing, result. Fold progress is a single `Double` from 0 to 1 that the melt animation reads; it is fed by the hinge angle, the pinch scale, the seam-hold ramp, or a debug slider, so every trigger produces the same animation.

**Surfaces.** A `SurfaceModel` protocol with seven implementations. Each knows how to `capture()` itself into a `SurfaceSnapshot`: a title, up to 8k characters of extracted text, an optional image, and structured metadata (URL, latitude/longitude, event times, page count). Web uses WebKit and reads the DOM; Maps uses MapKit and snapshots the region; Calendar uses EventKit and serializes real events; Files uses PDFKit; Photo and Clipboard hand over pixels. Adding a surface is a model, a view, and two registry lines.

**Engine.** One vision call to `gpt-6-sol` with `response_format: json_object`. The system prompt is a router: it describes the artifact catalogue (itinerary, event, email, quiz, grade, slides, code, diff, table, checklist, image_edit, markdown) with a "use for" sentence each, and asks for exactly one. The decoder is lenient on purpose: alternate key names are accepted, unknown types fall back to markdown, and a model that returns prose still renders something. Image artifacts trigger a second call to `gpt-image-1` with both screen images as references.

**Hinge.** `onHingeChange` drives `AppModel.handleHinge`. Melt progress is `(165 − degrees) / 135`, clamped. The fuse fires on the transition to `.closed` and re-arms when the angle passes 120° on the way back open, so a half-fold to peek at the melt never fires accidentally. `reservedRegions(kind: .division)` places the seam core and splits the stage; on a non-folding device it falls back to a midline so the app still runs.

**Services.** RevenueCat gates `fuse()` behind a `pro` entitlement with a free daily quota and a RevenueCatUI paywall. Supabase stores every public fuse (recipe, title, summary, artifact JSON, device) for a community feed and history. Speech turns hold-to-talk into an instruction. App Intents post commands onto a bus the model drains.

**Tooling.** XcodeGen project, xcconfig-based secrets with an in-app override so judges can paste keys without rebuilding.

## Challenges

**Making the fold feel like the cause.** If the melt lags the hinge by even a frame the illusion breaks and it reads as an animation that happens to play when you fold. We ended up driving the pane transforms from the hinge angle with an interpolating spring tuned for a 120 stiffness so it tracks the hand but does not jitter.

**Firing exactly once.** The hinge reports many angles near closed, some out of order. We arm on open, fire on the first closed transition, and only re-arm above 120°. Simple, but it took a few tries to get a fold you can trust.

**A prompt that decides.** Early prompts hedged: "here are three things you could do." A router that produces one artifact needed a catalogue with explicit "use for" guidance, a quality bar written for the judges ("Hagrid's at 9:05 before the line hits 90 min" beats "visit popular rides early"), and a hard rule against inventing coordinates.

**Real data on both screens.** The model is only as good as the snapshot. Getting readable text out of a web page, real event times out of EventKit, and coordinates out of a map pin, all within a second of the fold, drove most of the surface work.

## Accomplishments

- A physical gesture that produces a result, with an animation that follows the hinge angle frame for frame.
- One engine call that handles nine different kinds of output with no feature menu.
- Seven live surfaces and twelve artifact renderers, built in a weekend by four people.
- Five ways to trigger a fuse, all producing the same melt, including Back Tap on a closed phone.
- Follow-ups that turn one fold into a chain: grade a test, then generate a quiz on the weak spots, without touching the screens.

## What we learned

Constraints on the model matter more than cleverness in the prompt. Once the catalogue and the "use for" sentences were right, the model's choices became predictable, and the demo became reliable.

Hinge angle is a first-class input, on par with touch. Treating it as a layout event wastes it. Apple's guidance to use the hinge for interaction and effects, and reserved regions for layout, turned out to be the right split for us.

A lenient decoder buys more reliability than a stricter prompt. The model will occasionally write `lat` instead of `latitude` or wrap JSON in a fence. Accepting that costs nothing and prevents blank screens.

## What's next

- A Surfaces SDK so other apps can register their own live state and be fused with.
- Three-screen fuses: cover display as a third input while the phone is closed.
- On-device routing for the common pairs, with the cloud model for everything else.
- Shared fuses: two Duos, one on each side of a table, fold toward each other.

## Built with

Swift, SwiftUI, iOS 27.1 iPhone Duo APIs, Bitrig, Xcode 27.1, OpenAI gpt-6-sol and gpt-image-1, Supabase, RevenueCat, App Intents, WebKit, MapKit, EventKit, PDFKit, Speech, XcodeGen

## New APIs used

- `onHingeChange` (iOS 27.1) — continuous hinge angle and status; drives the melt and the trigger
- `DeviceHinge` — `angle`, `status` (`.closed`, `.partiallyOpen`, `.fullyOpen`)
- `GeometryProxy.reservedRegions(kind: .division, options: [.includeInactive])` — physical fold location for layout
- Cover display rendering while closed
- Liquid Glass (`glassEffect`) for chrome
- `MeshGradient` for the stage background
- `@Observable` / Observation framework throughout, no `ObservableObject`
- App Intents for Back Tap, Action Button and Siri triggers

## Prizes

Please opt this submission in for the RevenueCat prize. Fuse Pro (unlimited fuses) is implemented with the RevenueCat SDK and a RevenueCatUI paywall, gated at the single point where every trigger converges.

Repository: https://github.com/OjasMishra32/fuse
