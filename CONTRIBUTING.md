# Contributing to Fuse

Four of us, one weekend. This is how we stay out of each other's way.

## Build and run

```sh
brew install xcodegen           # once
xcodegen generate && open Fuse.xcodeproj
```

Choose the iPhone Duo run destination and run. In the simulator, hold Option to reveal the hinge slider; in the Bitrig 3D view you can grab the phone and fold it directly. Triple-tap the hinge badge in the app to open the dev panel, which has a fold slider that drives the same melt without a hinge.

Regenerate the project whenever you add or move files. `Fuse.xcodeproj` is a build product; edit `project.yml`, not the project.

Keys: copy `Config/Secrets.example.xcconfig` to `Config/Secrets.local.xcconfig` (git-ignored) and fill it in, or paste keys at runtime in Settings › Keys. Never commit a key. Store the Supabase project ref only, not the URL, because xcconfig treats `//` as a comment.

## Layout

```
Fuse/
  App/        AppModel (state machine), AppConfig (keys), DemoScenarios
  Design/     Theme: palette, motion, glass chrome, haptics
  Engine/     Prompts, FuseEngine, OpenAIClient, FuseResult (artifact models)
  Hinge/      onHingeChange → AppModel, FoldGeometry, HingeBadge
  Surfaces/   Surface.swift (contract + registry) and one file per surface
  Results/    one renderer per artifact
  Services/   RevenueCatService, SupabaseService, HistoryStore, SpeechService
  Intents/    App Intents → AppCommandBus
Config/       xcconfig
supabase/     schema.sql
docs/         demo script, Devpost draft
```

## Add a surface

A surface is a live mini-app on one half of the Duo. It owns its state and knows how to describe that state to the model. Everything lives in `Fuse/Surfaces/`.

1. **Kind.** Add a case to `SurfaceKind` in `Surface.swift`. Fill in `title`, `symbol` (SF Symbol) and `tint`.
2. **Model.** Create `<Name>SurfaceModel.swift`:

   ```swift
   @MainActor
   @Observable
   final class RecipeSurfaceModel: SurfaceModel {
       let kind: SurfaceKind = .recipe
       var headline: String { … }          // one line for the pane header
       var hasContent: Bool { … }          // gates readiness
       var thumbnail: UIImage? { … }       // cheap preview for the melt, or nil
       func capture() async -> SurfaceSnapshot { … }
       func apply(_ preset: SurfacePreset) { … }
       func reset() { … }
   }
   ```

   `capture()` is what the model sees. Return a `SurfaceSnapshot` with a real title, text clipped with `.fuseClipped()` (8k default), an image if pixels matter, and `metadata` for anything structured (URL, coordinates, dates). Handle every `SurfacePreset` case you can and ignore the rest.
3. **View.** Create `<Name>SurfaceView(model:)`. Use `SurfaceEmptyState` when there is nothing on the surface.
4. **Registry.** Add the kind to `SurfaceRegistry.dockOrder`, `makeModel` and `view(for:)`.

Nothing in the engine changes. `Prompts.describe` renders every snapshot the same way.

## Add an artifact type

An artifact is one kind of structured result. Four edits, all small.

1. **Model.** In `Fuse/Engine/FuseResult.swift`, add a `Codable, Hashable` struct with a lenient `init(from:)` (default every field, accept alternate key names the model might use). Add a case to `FuseArtifact`, a `typeName`, a `symbol`, and a branch in the decoder `switch` listing the wire names you accept.
2. **Catalogue.** In `Fuse/Engine/Prompts.swift`, add one line to the artifact catalogue: the JSON shape with field names, then a `Use for:` sentence. This is how the router learns when to pick your artifact. Be specific about the pairings that should produce it.
3. **Renderer.** Add `Fuse/Results/<Name>ArtifactView.swift`. Use `ResultCard`, `Eyebrow` and the `Theme` fonts. Add the case to the result view's `switch`.
4. **Plain text.** If `FuseResult.plainText` (used to stage a result back onto a screen) does not already cover your case, add it.

Try it with a demo scenario whose two screens obviously call for the new artifact. If the router does not pick it, the catalogue line is unclear; fix the prompt, not the decoder.

## Add a demo scenario

Append to `DemoScenario.all` in `Fuse/App/DemoScenarios.swift`:

```swift
DemoScenario(
    id: "kebab-case-id",
    title: "Short title",
    subtitle: "Left + right → result",          // ≤ 8 words
    symbol: "sf.symbol.name",
    left: .notes(DemoText.something),           // or .web(url), .place(name, lat, lon), .sampleCalendar
    right: .place("Name", 0.0, 0.0),
    instruction: nil                            // or a spoken instruction
)
```

Put the long text in `DemoText`. Both screens must carry concrete content: names, numbers, dates, addresses. Generic input produces generic output, and generic output loses demos. Prefer Wikipedia URLs for web surfaces; they always load. The `id` is what `fuse://demo/<id>` and the "Run demo" intent use.

## Conventions

- **Swift 5 language mode**, `SWIFT_STRICT_CONCURRENCY = minimal`. Do not turn on Swift 6 mode this weekend.
- **`@Observable` only.** No `ObservableObject`, no `@Published`, no `@StateObject`. Pass models with `@Bindable` when you need bindings.
- **`@MainActor` on every model and service** that touches UI state. Background work goes in a `Task`, results hop back with `Task { @MainActor in … }`.
- **Theme for everything visual.** Colors from `Theme`, fonts from `Font.fuse*`, radii from `Theme.radius*`, animations from `Theme.snappy / smooth / melt`. The violet-to-cyan energy gradient is reserved for the seam and anything that is fusing. Everything else stays neutral so the energy reads.
- **Haptics through `Haptics`.** Heavy on fuse, success on result, warning on failure.
- **Lenient decoding.** Anything the model writes gets a default. A blank screen is a bug; a slightly wrong render is not.
- **No new dependencies** without asking in the group chat. RevenueCat and Supabase are the two packages.
- **No `print` in committed code.** Use the failed phase and `flash()` for anything the user should see.
- File names match the type they contain. One surface per file, one renderer per file.

## Git

- `main` is always buildable. Do not push to it directly.
- Short-lived branches named `<you>/<thing>`: `maya/calendar-surface`, `sam/diff-renderer`. Branch, commit often, open a PR to `main`, one teammate glances at it, squash-merge, delete the branch. Aim for PRs that live under an hour.
- Run `xcodegen generate` and build on the Duo simulator before opening a PR.
- Commit messages in the imperative: "Add calendar surface", "Fix double fire on hinge jitter".
- If you touch `Surface.swift`, `FuseResult.swift` or `Prompts.swift`, say so in the chat first; those files are shared and merge conflicts there cost the most.
- Never commit `Config/Secrets.local.xcconfig` or any key. If one slips through, rotate it immediately.

## Demo-day rules

- Nothing merges to `main` in the last 90 minutes unless it fixes a crash on the demo path.
- The eight demo scenarios are the demo path. Run all eight before every merge in the final two hours.
