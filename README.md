# Fuse

**Put one thing on each screen. Fold the phone. Get the one result that only makes sense because both were there.**

Fuse is a SwiftUI app for the iPhone Duo. Each half of the open device hosts a live mini-app: a web page, a map pin, a note, a photo, a PDF, your calendar, the clipboard. When you fold the phone closed, Fuse captures both screens, sends their live state to OpenAI, and hands you back a single structured artifact: an itinerary, a calendar event with conflicts, a graded test, a redlined contract, a tailored cover email, a pitch deck.

The hinge is not navigation. It is the command.

Built in a weekend for Bitrig Hacks, iPhone Duo Edition.

## What it is

Most foldable software treats the second screen as more room. Fuse treats the fold as a verb. Two screens hold two things; closing them says "combine these." There is no feature menu. The relationship between the two screens is the feature, and the model decides what the most useful combination is.

Some pairs and what they produce:

| Left screen | Right screen | Result |
| --- | --- | --- |
| Theme park article | Map pin on the park | One-day itinerary with times and coordinates |
| Conference confirmation email | Your week | Calendar event, with the conflicts called out |
| Practice test with answer key | Your answers | Grade report, weak spots, next steps |
| Job posting | Resume | Cover email that quotes both |
| Vendor contract clauses | Procurement policy | Redline with reasons |
| Your calendar | A pin | Day ordered geographically, with leave-by times |
| Wikipedia article | Blog draft | Contradictions table |
| Messy notes | Background article | Six-slide pitch |
| Photo | Visual reference | Edited photo (gpt-image-1) |

Every result comes with follow-ups ("Make a practice test on my weak spots"), which re-fuse the same two screens with a new instruction.

## The interaction

1. Open the Duo. Left and right panes each show a surface dock; pick one and put something on it.
2. Start folding. From about 165° the two panes begin to melt toward the seam. The melt is driven directly by the hinge angle, so you can stop halfway and it stops with you.
3. Close the phone. At the closed state Fuse fires, both surfaces capture themselves, and the result renders on the cover display. Open the phone and it is waiting for you across both screens.

The fold is the primary input. Everything else is a stand-in for people who cannot fold right now.

## Physical inputs

| Input | How | Notes |
| --- | --- | --- |
| Fold | `onHingeChange` | Melt follows the angle; the fuse fires on `.closed`. Re-arms when you reopen past 120°. |
| Pinch | Pinch the two halves toward each other | Gesture scale drives the same melt; completing the pinch fuses. |
| Hold the seam | Press and hold the core at the division | A ramp fills; release at the top to fuse. |
| Hold to talk | Hold the mic and speak | `SpeechService` transcribes; the transcript becomes the instruction and the fuse fires when you let go. |
| Back Tap / Action Button / Siri | App Intents via Shortcuts | Intents post `AppCommand` values (`.fuse`, `.listen`, `.reset`, `.demo(id)`) onto `AppCommandBus`; `AppModel.handle` runs them. |

### Bind Back Tap to Fuse

1. Open Shortcuts, tap +, search for the Fuse app and add its "Fuse" action. Name the shortcut "Fuse".
2. Open Settings › Accessibility › Touch › Back Tap.
3. Choose Double Tap (or Triple Tap).
4. Scroll to the Shortcuts section and pick "Fuse".

Now a double tap on the back of the closed Duo fuses whatever is on the two screens. The same shortcut can be assigned in Settings › Action Button › Shortcut, and "Hey Siri, Fuse" works once the shortcut exists.

## Architecture

```
┌──────────────────────── iPhone Duo (open) ────────────────────────┐
│  LEFT PANE                        │  RIGHT PANE                    │
│  one live surface:                │  one live surface:             │
│  web · maps · notes · photo ·     │  web · maps · notes · photo ·  │
│  document · calendar · clipboard  │  document · calendar · clipboard│
└──────────────────┬────────────────┴────────────────┬───────────────┘
                   │ capture()                       │ capture()
                   ▼                                 ▼
            SurfaceSnapshot                   SurfaceSnapshot
   title · text (≤ 8k chars) · image · metadata (url, lat/lon, dates…)
                   └────────────────┬────────────────┘
                                    │  + spoken instruction (Speech)
                                    ▼
                               FuseEngine
              Prompts.system + Prompts.describe(left) + describe(right)
              ──▶ OpenAI gpt-6-sol  (vision, response_format: json_object)
              ──▶ gpt-image-1       (only for image_edit artifacts)
                                    │
                                    ▼
                               FuseResult
              recipe · title · summary · artifact · follow_ups
                                    │
            ┌───────────────────────┼────────────────────────┐
            ▼                       ▼                        ▼
      Results/ renderers      HistoryStore            SupabaseService
      itinerary · event ·     (on device)             community feed +
      email · quiz · grade ·                          fuse history
      slides · code · diff ·
      table · checklist ·
      image · markdown
                        RevenueCatService gates fuse() → Fuse Pro paywall
```

Key files:

- `Fuse/App/AppModel.swift` — the state machine (`compose → fusing → result`), every trigger, fold progress.
- `Fuse/Hinge/HingeMonitor.swift` — `onHingeChange` → `AppModel.handleHinge`; `FoldGeometry` resolves the division region.
- `Fuse/Surfaces/Surface.swift` — `SurfaceKind`, `SurfaceSnapshot`, `SurfacePreset`, `SurfaceModel`, `Pane`, `SurfaceRegistry`.
- `Fuse/Engine/Prompts.swift` — the router prompt and the artifact catalogue.
- `Fuse/Engine/FuseEngine.swift` — snapshots + instruction → `FuseResult`; lenient JSON decoding.
- `Fuse/Engine/FuseResult.swift` — `FuseResult`, `FuseArtifact` and every artifact model.
- `Fuse/App/DemoScenarios.swift` — eight seeded scenarios for the demo menu, deep links and the "Run demo" intent.
- `Fuse/Design/Theme.swift` — palette, motion, glass chrome, haptics.

## iPhone Duo APIs used

- `onHingeChange { old, new in … }` — continuous hinge angle and `DeviceHinge.Status` (`.closed`, `.partiallyOpen`, `.fullyOpen`). Drives the melt and the trigger.
- `DeviceHinge` — angle in degrees, exposed in the live `HingeBadge`.
- `GeometryProxy.reservedRegions(kind: .division, options: [.includeInactive])` — where the fold physically is, used to place the seam core and split the stage. Falls back to a midline on non-folding devices.
- Cover display — the result renders on the outer screen while the phone is closed, then re-lays out across both panes on reopen.

Per Apple's guidance the hinge is used for interaction and effects, and reserved regions are used for layout. Fuse does not read other apps' screens; every surface is Fuse's own.

## Setup

Requirements: Xcode 27.1 beta with the iPhone Duo simulator (Bitrig), and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
git clone https://github.com/OjasMishra32/fuse.git && cd fuse
xcodegen generate
open Fuse.xcodeproj
```

Choose the iPhone Duo run destination and run. In the simulator, hold Option to reveal the hinge slider, or grab the phone in the 3D view and fold it.

### Keys

Fuse resolves every key in this order: value pasted in the app (Settings › Keys) → `Info.plist` filled from xcconfig at build time → empty.

Option A, build-time:

```sh
cp Config/Secrets.example.xcconfig Config/Secrets.local.xcconfig
# fill in OPENAI_API_KEY, SUPABASE_PROJECT_REF, SUPABASE_ANON_KEY, REVENUECAT_API_KEY
xcodegen generate
```

`Secrets.local.xcconfig` is git-ignored. Store only the Supabase project ref (the `abcdefgh` in `https://abcdefgh.supabase.co`), not the URL — xcconfig treats `//` as a comment.

Option B, runtime: open the app, tap the gear, paste keys. Works on any device without rebuilding.

| Key | Used for | Default |
| --- | --- | --- |
| `OPENAI_API_KEY` | Router (vision + JSON) and image edits | required |
| `OPENAI_MODEL` | Router model | `gpt-6-sol` |
| `SUPABASE_PROJECT_REF`, `SUPABASE_ANON_KEY` | Community feed and history | optional; feed disabled without them |
| `REVENUECAT_API_KEY` | Fuse Pro entitlement and paywall | optional; a RevenueCat test store key (`test_…`) works |

### Supabase

Create a project, open the SQL editor, run `supabase/schema.sql`. It creates the `fuses` table the community feed reads and writes (recipe, title, summary, artifact JSON, device, timestamp, public flag) with row-level security allowing anonymous inserts and public reads.

### RevenueCat

Create a project with a test store, add an entitlement named `pro` attached to a monthly product, and paste the public key. `RevenueCatService.canFuse` gates every trigger; when the free quota is spent the paywall sheet (RevenueCatUI) is presented instead of fusing.

## Extending Fuse

### Add a surface

A surface is a live mini-app that knows how to describe itself to the model.

1. Add a case to `SurfaceKind` in `Fuse/Surfaces/Surface.swift` and give it a `title`, `symbol` and `tint`.
2. Create `<Name>SurfaceModel` (`@MainActor @Observable`, conforming to `SurfaceModel`) and `<Name>SurfaceView(model:)`. The model's `capture()` returns a `SurfaceSnapshot` with a title, clipped text, an optional image and structured metadata.
3. Wire both into `SurfaceRegistry.makeModel` and `SurfaceRegistry.view(for:)`, and add the kind to `dockOrder`.

Nothing else changes. The engine describes snapshots generically.

### Add an artifact

1. Add a model and a `FuseArtifact` case in `Fuse/Engine/FuseResult.swift`, plus a decoder branch with the wire name(s) and a `symbol`.
2. Add one line to the artifact catalogue in `Fuse/Engine/Prompts.swift`: the JSON shape and a "Use for:" sentence. This is what teaches the router when to pick it.
3. Add a renderer in `Fuse/Results/` and a case in the result switch.

### Add a demo scenario

Append a `DemoScenario` to `DemoScenario.all` in `Fuse/App/DemoScenarios.swift`. Both inputs should carry concrete, specific content; the router is only as good as what is on the screens.

## Docs

- `docs/DEMO_SCRIPT.md` — the three-minute demo, with timestamps.
- `docs/DEVPOST.md` — the Devpost submission draft.
- `CONTRIBUTING.md` — conventions, workflow, how to build for the Duo simulator.

## Team

| Name | Role | GitHub |
| --- | --- | --- |
| Ojas Mishra | | [@OjasMishra32](https://github.com/OjasMishra32) |
| | | |
| | | |
| | | |
