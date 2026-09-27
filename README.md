# Fuse

**Put one thing on each screen. Fold the phone. Get the one result that only makes sense because both were there.**

Fuse is a SwiftUI app for the iPhone Duo. Each half of the open device hosts a live mini-app: a web page, a map pin, a note, a photo, a PDF, your calendar, the clipboard. When you fold the phone closed, Fuse captures both screens, sends their live state to OpenAI, and hands you back a single structured artifact: an itinerary, a calendar event with conflicts, a graded test, a redlined contract, a tailored cover email, a pitch deck.

The hinge is not navigation. It is the command.

Built in a weekend for Bitrig Hacks, iPhone Duo Edition.

## Sponsors, and what each one does in Fuse

| Sponsor | Where it lives | What it powers |
|---|---|---|
| **OpenAI** | `Fuse/Engine/OpenAIClient.swift`, `FuseEngine.swift`, `Prompts.swift`, `IntentPreview.swift` | `gpt-6-sol` reads both screens (text + pixels) and writes the typed result; a second pre-read proposes the top three fuses on the seam before you fold; `gpt-image-2` composes one image from the two screens' photos. |
| **RevenueCat** | `Fuse/Services/RevenueCatService.swift`, `Fuse/Screens/PaywallView.swift`, `FuseControls` | Purchases SDK configured at launch, `pro` entitlement, customer info stream, custom paywall (test store or demo mode), free quota bookkeeping. Opted in for the RevenueCat prize. |
| **Supabase** | `Fuse/Services/SupabaseService.swift`, `Fuse/Screens/CommunityView.swift`, `supabase/schema.sql` | Anonymous auth, `fuses` table with RLS, every result recorded, public community feed with pull-to-refresh. |
| **Bitrig / Xcode 27.1** | whole project | Built and filmed on the iPhone Duo simulator; `onHingeChange`, `reservedRegions(.division)`, cover display. |

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
| A map pin where you're staying (a city you don't know) | A late-night food list with hours | Everything you can still reach and sit down at before it closes, soonest first, with leave-by times and walking directions |
| Wikipedia article | Blog draft | Contradictions table |
| Messy notes | Background article | Six-slide pitch |
| Room photo | Furniture photo | Furniture placed in your room (gpt-image-2) |
| Photo of a person (Safari) | Photo of another person (Safari) | One realistic photo of both of them together |
| Photo | Visual reference | Edited photo (gpt-image-2) |

Every result comes with follow-ups ("Make a practice test on my weak spots"), which re-fuse the same two screens with a new instruction.

### Fuse two images

Put a room photo on one Photo surface and a furniture photo on the other, in either order. Fold, or say “Put this chair beside the window in my room.” Fuse sees both photos, chooses a visual composition for this pair, and sends both references to the image editor. The result view displays the generated image and offers **Save to Photos**. Requests to compare products or read documents still produce text.

For two real apps, use **Take Screenshot → Fuse Screens** with the instruction and layout filled in. A successful image result appears in the native result card and is saved in Fuse history. Background completion depends on the system's execution budget and API latency. See [the two-image test and demo guide](docs/IMAGE_FUSION.md) for setup, acceptance checks and demo limitations.


## Fuse anywhere

Any two real apps, side by side on the Duo, no Fuse open:

1. Shortcuts → new shortcut → add **Take Screenshot** → add **Fuse Screenshot** (from Fuse; it takes the screenshot as input) → name it *Fuse*.
2. Settings → Accessibility → Touch → **Back Tap** → Double Tap → *Fuse*. (Or assign it to the Action Button.)
3. Open Safari on one half and Maps, Messages, Mail, Calendar or a PDF on the other. Double-tap the back of the phone.

Fuse opens with the two halves of that screenshot as its two screens, melts them, and produces the result. Saying "Fuse my screen" to Siri does the same, and the plain **Fuse** shortcut with nothing on the halves uses the newest screenshot in Photos.

## Fuse inside Safari (works in the simulator)

Two Safari windows side by side, the way the Duo does multitasking. Tap Safari's extension button, tap **Fuse**: the popup lists the two pages you're reading, "Fuse these" runs the engine inside the extension, and the result appears right there over Safari. Nothing else opens. Open Fuse later and the same result is waiting in full.

One-time setup: Settings → Apps → Safari → Extensions → Fuse → on, allow on all websites; open Fuse once so it shares its key with the extension.

## Fuse follows you (works in the simulator)

You never have to start in Fuse.

- **Safari extension** — enable once: Settings → Apps → Safari → Extensions → Fuse → on, allow on all websites. From then on Fuse remembers the pages you read (URL, title, text, what you selected). Open Fuse from anywhere and the last two pages are already on the two halves; open it from the cover with the phone folded and it fuses immediately. The Fuse button in Safari's toolbar also puts the current page on a half in one tap.
- **Control Center** — add the *Fuse* control (Control Center → + → Fuse). One tap from any app opens Fuse and fuses what you were just doing.
- **Clipboard** — copy anything in any app; it's on a half when Fuse comes up.
- **Share sheet** — Share → Fuse → Left / Right / Both halves.
- **Siri / Spotlight** — "Fuse my screen", "Fuse with voice", or type Fuse in Spotlight.

## It is the phone

Fuse opens to a home screen. Tap Safari and it opens on the left half; tap Maps and it opens on the right — the way two apps sit side by side on the Duo. Each half shows only that app and an iOS home bar. Fold the phone, and the two apps you were using become the two inputs.

## Using your phone, not an app

Fuse is meant to sit underneath whatever you are already doing:

- **Send to Fuse** — from Safari, Photos, Files, Messages or any app, tap Share → *Fuse* → pick a half. The item lands on that half of the phone. Fold to fuse it with whatever is on the other half.
- **Live intent** — the moment both halves have something on them, the seam shows what the fold will do right now ("Fold: Plan the day", "Add to calendar", "Compare"). Folding runs the first one; tap another to pick it; hold the mic to say something else.
- **Back Tap / Action Button / Siri** — "Fuse" and "Fuse with Voice" are App Shortcuts, so a double tap on the back of the phone can fuse without opening anything.

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
              ──▶ gpt-image-2       (only for image_edit artifacts)
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
