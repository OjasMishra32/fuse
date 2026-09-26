# Fuse background overlay: implementation and test plan

Prepared September 26, 2026. Code reviewed at [`a7d65d2`](https://github.com/OjasMishra32/fuse/tree/a7d65d287c19fcbd96ebf7780e2a203f96efa84e), including the new screenshot intent, Control Center control, Safari extension, and deep links. This is a plan, not an implemented or simulator-tested feature. The review environment is Windows; runtime checks require a Mac with Xcode 27.1 and the Duo runtime.

## 1. The requirement

Two independent iOS apps are already open side by side. The user invokes Fuse through a system shortcut, optionally speaks an instruction, and receives a native system card. Fuse's main interface never becomes foreground during that operation. Dismissing the card leaves the original app pair in place.

Fuse may be installed and opened once for setup, keys, and permissions. Subsequent invocations must execute without requiring its scene to be active. Showing a screenshot inside a foreground Fuse window does not satisfy this requirement.

The first implementation uses a **background App Intent and a system-hosted snippet**. Screen capture supplies the input; the snippet supplies the visible card. iOS controls the card's presentation. This does not promise a freely positioned floating window, touch-through interaction with both apps, or background hinge delivery.

**First decision:** prove a fixed native snippet can appear over the existing app pair on the actual Duo simulator before building the rest.

## 2. Where the code is now

The repo has advanced since the initial discussion, but all existing invocation paths still lead into Fuse's foreground UI.

| Area | Current behavior | Consequence for this plan |
| --- | --- | --- |
| [Screenshot intent](https://github.com/OjasMishra32/fuse/blob/a7d65d287c19fcbd96ebf7780e2a203f96efa84e/Fuse/App/FuseIntents.swift#L36) | Accepts an optional `IntentFile`, writes it into `SharedInbox`, sends `.fuseScreenshot`, and sets `openAppWhenRun = true`. | Reuse the image-input contract, but execute directly and return a snippet. Changing the foreground flag alone is insufficient. |
| [Control Center intent](https://github.com/OjasMishra32/fuse/blob/a7d65d287c19fcbd96ebf7780e2a203f96efa84e/FuseControls/FuseControlIntent.swift#L3) | Opens Fuse and writes a shared command flag. | The existing button is an app launcher. It does not capture either source app or run the engine. |
| [RootView](https://github.com/OjasMishra32/fuse/blob/a7d65d287c19fcbd96ebf7780e2a203f96efa84e/Fuse/Screens/RootView.swift#L62) | Consumes commands, imports input on activation, and displays results. | Background execution must not depend on these view callbacks. |
| [Screenshot processing](https://github.com/OjasMishra32/fuse/blob/a7d65d287c19fcbd96ebf7780e2a203f96efa84e/Fuse/App/AppModel.swift#L413) | Splits the image, installs both crops into photo panes, clears the instruction, and starts the UI state machine. | Extract image preparation and preserve the explicit instruction. Do not construct panes for background work. |
| [Engine](https://github.com/OjasMishra32/fuse/blob/a7d65d287c19fcbd96ebf7780e2a203f96efa84e/Fuse/Engine/FuseEngine.swift#L24) | Already accepts two snapshots, optional instruction, screenshot framing, and progress. Returns `FuseResult`. | Reuse this core. The engine already supports the required screenshot inputs. |
| [Screenshot prompt](https://github.com/OjasMishra32/fuse/blob/a7d65d287c19fcbd96ebf7780e2a203f96efa84e/Fuse/Engine/Prompts.swift#L100) | Describes both images as captured app content. | Retain screenshot framing; make clear that only visible information is available. |
| [Photos fallback](https://github.com/OjasMishra32/fuse/blob/a7d65d287c19fcbd96ebf7780e2a203f96efa84e/Fuse/Services/LatestScreenshot.swift#L10) | Reads the newest screenshot, falling back to any recent photo. | Exclude this implicit fallback from the new route. A failed explicit screenshot must produce an error, not substitute another image. |
| [Safari intake](https://github.com/OjasMishra32/fuse/blob/a7d65d287c19fcbd96ebf7780e2a203f96efa84e/Fuse/App/AppModel.swift#L341) | Opens the last two recorded URLs inside Fuse. | Useful optional context, but it does not represent the two currently visible apps. Keep it out of the primary flow. |
| [Configuration](https://github.com/OjasMishra32/fuse/blob/a7d65d287c19fcbd96ebf7780e2a203f96efa84e/Fuse/App/AppConfig.swift#L54) | Reads `UserDefaults.standard` and the current bundle's plist. | Keep the first background intent in the main app target so it can use existing configuration. Extension execution needs separate configuration and target design. |
| [Existing tests](https://github.com/OjasMishra32/fuse/blob/a7d65d287c19fcbd96ebf7780e2a203f96efa84e/FuseTests/FuseEngineTests.swift#L4) | Cover decoding, configuration, prompts, dates, and demo data. | There is no existing coverage for screenshot handoff, background execution, or native snippets. |

### Existing bug to account for

[`importInbox()`](https://github.com/OjasMishra32/fuse/blob/a7d65d287c19fcbd96ebf7780e2a203f96efa84e/Fuse/App/AppModel.swift#L376) starts a fuse when it encounters a screenshot. At the end, it calls `dismissResult()` because the phase is no longer compose. That resets `screenshotMode`. The `.fuseScreenshot` command then sees screenshot mode off and can start a Photos fallback, potentially replacing the first request.

The new path must validate one explicit request and execute it once. It must bypass the inbox/command-bus sequence. If the old screenshot route is retained, fix it separately by completing intake before starting one operation.

Two other details matter: the current midpoint splitter guesses layout from aspect ratio, and `fuseScreenshot()` erases the instruction. Neither behavior should be carried into the background service unchanged.

## 3. Proposed user flow and architecture

```text
Two independent source apps remain open
    -> invoke system shortcut
    -> Take Screenshot, before any dictation/card UI appears
    -> optional Dictate Text
    -> Fuse Screens: background intent(image, instruction, layout)
    -> validate and crop -> existing FuseEngine -> persist result
    -> iOS presents native result snippet
    -> Done returns to the original app pair
```

The first version shows a compact result, a Copy action if supported by the host, and the system's dismissal control. Add input thumbnails and one refinement action after this works. A preview/confirmation snippet can be added later without opening Fuse.

The screenshot remains model input. It is never used as a replacement workspace behind a foreground Fuse interface.

## 4. Simulator feasibility tests, in order

Record each test as **PASS**, **FAIL**, or **NOT TESTED**. The starting status of every runtime test below is **NOT TESTED**. A successful test in another simulator or on a physical iPhone does not establish Duo simulator support.

### Gate A: native card without a foreground Fuse scene

Suggested timebox: 20–30 minutes after the baseline project builds. This is a planning limit, not an estimate of proven implementation time.

1. Record Xcode, SDK, simulator runtime, and device identifier. Build the current app once. Confirm two independent simulator-compatible apps can be arranged side by side with distinct visible test content.
2. Add a temporary `FuseOverlayProbeIntent` to the **main app target** and register it as an App Shortcut. Configure `supportedModes` as `.background`. Return a fixed native snippet immediately. Do not call `AppModel`, `AppCommandBus`, deep links, or `RootView`.
3. Invoke it through an available system launcher while the two source apps are visible. Try the built-in Run Shortcut control if the runtime provides it. Launching from an already foregrounded Shortcuts editor is only a diagnostic check, not a pass for the required experience.
4. Log intent execution mode and all Fuse scene activation events. Record the screen from before invocation through dismissal.

**Pass:** the system card appears over the existing pair, Fuse never activates a foreground scene, and dismissal restores the same pair. A probe that succeeds only by opening Fuse fails.

**If it fails:** check intent registration, launcher behavior, and the minimal probe target separately. If existing embedded extensions prevent installation, use a temporary app-only probe target to isolate the platform test; preserve the existing targets. If that configuration is required, carry an app-only build configuration through the real implementation and tests, then repeat Gate A in that final target. A probe-only success is insufficient. Do not proceed to a full UI rewrite or disguise a foreground window as a passing overlay.

### Gate B: an interactive native card

Return a `SnippetIntent` with a small view and an App-Intent-backed button that changes a stored counter. Repeated rendering must only read state. Button actions may change state; rendering must not start model calls.

**Pass:** the counter updates without activating Fuse. This establishes a route for later Copy/refinement actions, subject to each action's own test.

### Gate C: capture the actual two-app workspace

Create a shortcut with `Take Screenshot -> Fuse Capture Probe(image)`. The probe decodes the image and displays its dimensions and two thumbnails in a snippet. Do not call the model.

**Pass:** the pixels contain both original source apps, with recognizable content from each. They must not contain Control Center, a Shortcuts editor, dictation UI, or an older Fuse card. Repeat after changing visible text in one source to prove capture freshness.

Start with one fixed, documented orientation and equal split. Test rotated images and unequal splits before claiming general layout support. Capture precedes every visible prompt. If launcher timing contaminates the screenshot, record that failure; investigate the timing or the optional capture-session route below.

### Gate D: voice independently of hinge sensing

Extend the shortcut to `Take Screenshot -> Dictate Text -> Fuse Capture Probe(image, instruction)`. Return the transcript and thumbnails without inference.

**Pass:** the correct transcript and original inputs appear, cancellation does not start processing, and Fuse remains backgrounded. If this runtime lacks working dictation, test a typed instruction as an explicitly labeled fallback. Voice can later be added without changing the engine contract.

The exact Screenshot/Dictate Text combination on Duo is an experiment, not a capability verified by this review. A snippet does not establish permission or lifecycle support for running the existing microphone service inside it.

### Gate E: background processing and runtime limits

First return a deterministic local result through the new service. Then run one real screenshot-and-instruction model request and display its result in the native card.

Test a fresh app process and an already-running background process. Record request start, completion, errors, and scene activation. Test cancellation, offline operation, an invalid key, and one delayed response.

**Pass:** result or useful error returns without opening Fuse; one invocation makes one engine call; cancellation prevents late result presentation and usage updates. Persist the result before returning it to the snippet.

The current client allows 120-second request and 180-second resource timeouts. Those settings do not grant equivalent background execution time. Start with a short text-output task. If necessary, evaluate iOS 27 `LongRunningIntent` with the installed SDK and a separate runtime test. Report real progress and handle cancellation; do not invent timer-based progress to keep work alive. See [Apple's runtime API](https://developer.apple.com/documentation/appintents/longrunningintent).

## 5. Implementation after the gates pass

Keep the first working route in the main app target. Do not add an App Intents extension or move the engine into the widget target just to prove this feature.

| File or component | Planned change |
| --- | --- |
| `Fuse/App/FuseIntents.swift` | Add a distinct background `FuseScreensIntent` during development. Require screenshot input, accept an optional instruction and explicit layout, execute the service directly, and return a native snippet. Keep the old action available until existing shortcuts can be migrated. |
| New `Fuse/Services/BackgroundFuseService.swift` | Own validation, crop preparation, inference, cancellation, and exactly-once completion for an invocation ID. No view, scene, pane, or URL-navigation dependency. Inject the engine boundary for meaningful tests. |
| New `Fuse/Services/ScreenshotInput.swift` | Decode and normalize orientation, validate dimensions, crop using an explicit axis/divider, and construct two `SurfaceSnapshot` values. Reject unusable input. |
| New `Fuse/Services/FuseJobStore.swift` | Store invocation ID, input references, instruction, state, result, and timestamps. Serialize writes and save atomically. Give snippet intents a stable job ID, not large image parameters or an in-memory `AppModel`. |
| New `Fuse/Intents/FuseSnippetIntent.swift` and `Fuse/Snippets/FuseSnippetView.swift` | Read a completed job and render a compact native card. Use App Intent buttons for actions. Snippet reevaluation must not rerun inference. |
| `Fuse/Engine/FuseEngine.swift` and `Prompts.swift` | Reuse the existing snapshot engine and screenshot framing. Limit the first demo to text/email/checklist outputs. Enforce the allowed artifact types in code before the engine can issue its second image-generation/edit request; prompt wording alone is insufficient. Preserve the spoken instruction. |
| `Fuse/Engine/OpenAIClient.swift` | Make request lifetime and cancellation compatible with the background action. Support a test transport or equivalent injection. Keep provider behavior unchanged unless testing identifies a necessary change. |
| `Fuse/App/AppModel.swift` | Extract reusable screenshot preparation. Correct the legacy inbox/reset bug if retaining that route. Do not use this UI model as the new background worker. |
| `project.yml` | Register source/target changes here and regenerate the Xcode project. Add no new package dependencies for the core path. |
| `README.md` and `docs/DEMO_SCRIPT.md` | Document the tested invocation path, runtime, setup, supported layouts, and unverified hinge behavior. Distinguish internal panes from actual external apps. |

### Execution and persistence rules

- An explicit image is authoritative. Decode/write failures return a clear error; they never trigger a Photos or Safari fallback.
- Preserve the instruction through preparation and follow-ups. Crops are images of app content, not a request to edit the images themselves.
- For the MVP, use the measured divider of a fixed demo layout. Do not claim that the physical hinge, the screen midpoint, and the multitasking divider are always identical.
- Normalize image orientation before pixel cropping. Preserve odd edge pixels, reject zero-sized crops, and crop before downscaling. The current image encoder caps the longest edge at 1024; verify text legibility before changing this limit or adding OCR.
- Await all work needed for the intent's result. A detached task plus an immediate successful return does not establish reliable background completion.
- Use a stable invocation ID for retries and snippet actions. Parallel jobs must not overwrite each other's inputs or results. Repeated snippet rendering must not incur another model request.
- The existing App Group can hold job files if multiple targets later need access. It does not automatically share `UserDefaults.standard`, bundle configuration, or in-memory singletons. Keep keys out of snippet parameters and logs.
- Retain input crops only as long as needed for the active result/follow-up session. Define cleanup and an expiry policy; an expired job should show an error rather than silently capture a different screen.
- Preserve applicable usage checks in the service, but return an error/status card rather than opening Settings or a paywall. Record successful usage once.
- Do not inherit the public-upload side effect from [`AppModel.finish`](https://github.com/OjasMishra32/fuse/blob/a7d65d287c19fcbd96ebf7780e2a203f96efa84e/Fuse/App/AppModel.swift#L240): it currently records results with `isPublic: true` when Supabase is configured. Keep external-app results local by default in this route.
- Existing full-screen artifact renderers can inform the card design, but should not be embedded wholesale. Keep the first card short enough for the host's limits, with a plain-text result available to the Shortcut as a fallback output.

## 6. Optional work, kept separate from the core path

**Custom Control Center button.** Only attempt this after a system Shortcut launcher passes Gate A. The current `FuseControls` target contains its own sources and `Shared`, not the engine. Choose a supported way to invoke the proven shortcut/background action, then test that host independently. A Control Widget does not automatically receive a screenshot argument. Do not assume a snippet that works through a Shortcut also works from a directly invoked custom control.

**Continuous capture.** If a one-shot Shortcut capture cannot obtain the unobstructed workspace, test ScreenCaptureKit's user-approved full-display session and `screen-capture` background mode. Buffer the last unobstructed frame before the launcher or snippet appears. Verify which display is captured when folding. Its iOS documentation does not establish that the Duo simulator implements the complete path. This is a larger experiment, not a prerequisite if one-shot capture works.

**Hinge trigger.** Test three contexts separately: Fuse foreground as a diagnostic baseline; Fuse background with only the two source apps visible; and a native snippet visible. Log actual callback delivery. Only if the relevant context works should an angle band, dwell timer, one-shot trigger, and re-arm rule be added. Opening from the background and controlling a visible snippet are separate claims. No callbacks means the native demo retains an explicit shortcut/button trigger.

**Voice from the hinge.** Requires both reliable background hinge delivery and a supported audio/input path in that context. A successful foreground `SpeechService` test is insufficient. Keep system dictation as the first voice path.

**Safari and clipboard enrichment.** Add later, with provenance and timestamps. The newest recorded URLs may be up to 45 minutes old and are not necessarily the apps the user can currently see. If Safari text is reused, consume the recorded text instead of reopening a web view that may lose the original authenticated state.

## 7. Validation that matters

Add focused automated tests for the new data/execution boundaries. A screenshot of a passing unit test cannot prove a system overlay; lifecycle acceptance remains a runtime test.

| Test | Required observation |
| --- | --- |
| Explicit screenshot input | No Photos read and no recents/clipboard lookup, including on decode failure. |
| One invocation | One engine call and one completed usage/history update, even if a snippet renders repeatedly. |
| Cropping | Known labeled images split correctly for supported layouts, orientation metadata, and odd dimensions. Invalid crops fail explicitly. |
| Instruction | The exact instruction reaches the engine and remains attached to the original input pair during refinement. |
| Artifact restriction | An unexpected image artifact cannot start an image API request on the background text-demo route. |
| Jobs and cancellation | Concurrent jobs stay separate; persisted results survive restart; cancellation does not publish a late success. |
| Background lifecycle | No Fuse scene becomes active from invocation through result dismissal, including a cold process. |
| Real capture freshness | Change a visible identifier in each source and confirm the next result uses the new capture. |
| Error behavior | Missing key, denied input, offline network, and timeout produce a card or Shortcut error without foreground navigation. |

Use structured development logs containing invocation ID, launcher, execution mode, scene state, capture dimensions/time, stage, duration, and outcome. Do not log keys, screenshots, transcripts, or private message contents.

On the Mac, run the baseline build and the relevant tests after implementation. Commands below assume the repository is the current directory; replace the device placeholder with the actual Duo identifier:

```sh
xcodebuild -version
xcrun simctl list devices available
xcodegen generate
xcodebuild -project Fuse.xcodeproj -scheme Fuse -showdestinations
xcodebuild -project Fuse.xcodeproj -scheme Fuse -destination 'platform=iOS Simulator,id=<DUO_UDID>' build
xcodebuild -project Fuse.xcodeproj -scheme Fuse -destination 'platform=iOS Simulator,id=<DUO_UDID>' test
```

Run the existing engine tests and new boundary tests once the implementation stabilizes. Repeat runtime checks when changing the launcher, execution target, input capture, or snippet lifecycle.

## 8. Live and prerecorded demo readiness

**Live native demo:** require Gates A–E to pass on the exact demonstration runtime. As an acceptance target, complete three consecutive runs from the external app pair, including one cold Fuse process and one changed input. Keep a typed-instruction path available if microphone input is unreliable, and describe that fallback accurately. These are proposed readiness criteria, not completed results.

Use simulator-compatible source apps. Apple's Simulator cannot install App Store apps, so the native Gmail release is not an assumed dependency. Two independent simulator-built fixture apps can establish cross-app behavior; label their content as demo data. Gmail web is another candidate only after testing it on the runtime.

Record the actual live path once stable: source pair, invocation, input/voice, processing, result card, dismissal. A prerecorded demo can avoid stage-network and microphone variability. If latency is edited out, say so. If native execution fails and a concept video uses compositing or a Mac-hosted overlay, label it as a concept; that is not a passing implementation of the native feature.

**No-go rule:** if the Duo runtime cannot present a genuine snippet over the source pair without foregrounding Fuse, the strict native live demo is blocked. A foreground screenshot-backed app does not become an acceptable substitute. Document the failure and select a clearly labeled concept recording or a supported test device/environment.

## 9. Suggested work order

1. One developer proves Gates A–C. Keep other implementation limited until native presentation and real capture pass.
2. In parallel, another developer extracts screenshot preparation and writes the crop/input tests; a third prepares two independent demo sources and the repeatable runtime checklist.
3. After Gate C, build the background service and result store while the snippet view is implemented against a deterministic result fixture.
4. Integrate a real model call, then voice. Test cancellation and a cold process.
5. Add a compact refinement action. Investigate custom Control Center and hinge behavior only after the core route is demonstrable.
6. Freeze the demonstrated path, record one genuine run, and update the demo script with what actually passed.

## 10. Platform evidence and unresolved points

- [App Intent execution modes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes): background actions are supported without foregrounding the app.
- [Native snippet presentation](https://developer.apple.com/videos/play/wwdc2025/281/) and [snippet implementation](https://developer.apple.com/documentation/appintents/displaying-static-and-interactive-snippets): system-hosted cards and App Intent interactions are supported. The host controls presentation; runtime behavior must be tested.
- [LongRunningIntent](https://developer.apple.com/documentation/appintents/longrunningintent): optional iOS 27 execution support, with progress and cancellation obligations. It grants no general-purpose hinge monitoring.
- [ScreenCaptureKit on iOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios): user-selected full-display capture and background streaming are documented; exact Duo simulator support remains unverified.
- [Hinge interaction](https://developer.apple.com/documentation/uikit/uihingeinteraction): documented in terms of a view hierarchy, with no verified global/background trigger for this plan.
- [Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes): most app extensions cannot currently run/debug in the Duo simulator. Test the custom control separately.
- [Simulator app installation](https://developer.apple.com/library/archive/documentation/IDEs/Conceptual/iOS_Simulator_Guide/InteractingwiththeiOSSimulator/InteractingwiththeiOSSimulator.html): App Store installations are not supported in Simulator.

Older indexed snippet documentation prohibited Control Center snippets, while the current live article omits that statement. Neither the old restriction nor its omission proves current Duo behavior. The implementation plan therefore requires a separate launcher/host test and makes no promise about custom Control Center snippets.

**Next executable task:** add the fixed background overlay probe in the main app target and record Gate A on the Duo simulator. That result determines whether the remaining work can satisfy the no-foreground-Fuse requirement.
