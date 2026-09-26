# Two-image fusion

Fuse can use a room photo and a furniture photo to generate a visualization of that furniture in the room. The router sees both inputs, identifies their roles in either order, and chooses an `image_edit`. Both image files are then sent to OpenAI's image editor. The prompt preserves the room, camera viewpoint and furniture identity, and asks for consistent scale, perspective, lighting and contact shadows. It also carries the original spoken instruction and photo captions.

Other useful visual pairs include a person and clothing, or a subject and a style reference. A request to compare prices, extract text or explain a document still takes the normal text-artifact path. This remains a model decision; the manual checks below verify semantic quality that mocked tests cannot establish.

## Implementation

- `IntentPreviewer` now sees small image references instead of guessing from photo dimensions. Replacing a photo invalidates the old suggestions even if the replacement has the same dimensions.
- `Prompts` describes visual pairings and identifies image 1/image 2 as the attached LEFT/RIGHT sources. The room can be either reference. Screenshot framing also recognizes product photos and room photos inside apps.
- `FuseEngine` executes the edit using the supplied sources. Text-router base64 is ignored; only pixels returned by the image endpoint become the result. Cancellation is checked before and after rendering.
- `OpenAIClient` retains the existing `gpt-image-2` model, sends ordered `image[]` PNG parts, uses automatic output dimensions and medium quality, and keeps reference images up to 2048 pixels on the long edge. Invalid references and malformed output fail explicitly. HTTP error messages omit raw response bodies.
- The foreground result already displays images and saves them to Photos. `BackgroundFuseService` now preserves a generated image instead of replacing it with its text summary, and `FuseSnippetView` displays it. History and the local job store keep the image bytes.

The API contract follows the official [image editing reference](https://developers.openai.com/api/reference/resources/images/methods/edit) and [image generation guide](https://developers.openai.com/api/docs/guides/image-generation). No new package or generated-project change is required.

## Configure and build on a Mac

Use Xcode and the Duo runtime specified in `project.yml`. Configure an API key with access to the router model and `gpt-image-2` through **Settings → Keys**, or the existing ignored `Config/Secrets.local.xcconfig`. Do not add keys to source or screenshots. A 401 means the supplied credentials were rejected; it does not test image quality.

From the repository root:

```sh
xcodegen generate
xcodebuild -list -project Fuse.xcodeproj
xcrun simctl list devices available
xcodebuild test -project Fuse.xcodeproj -scheme Fuse \
  -destination 'platform=iOS Simulator,id=<DUO_SIMULATOR_UDID>' \
  -only-testing:FuseTests/FuseEngineTests \
  -only-testing:FuseTests/OpenAIImageTests \
  -only-testing:FuseTests/BackgroundFuseTests
```

Replace the destination placeholder with the installed Duo simulator's identifier. The test fixtures intercept their URLSession requests and do not contact OpenAI or spend credits. Tests cover ordered reference uploads, Retina sizing, invalid inputs, API failures, result persistence, visual previews and engine integration. They cannot establish whether generated furniture looks convincing.

This change was prepared on Windows, which cannot build the iOS target or run these XCTest suites. Xcode build, simulator rendering and live-model validation remain required before merging.

## Foreground acceptance checks

Import two clear photos into simulator Photos: a room with visible floor space and one identifiable piece of furniture, preferably against a plain background. Use your own or permitted demo images. Avoid private content.

1. Open a Photo surface on each half. Pick the room on the left and furniture on the right. Captions such as “my living room” and “green armchair” are optional.
2. Wait for the visual suggestion, then fold or use the seam trigger without an instruction. Expect an image result with both references represented, not a comparison table or collage.
3. Check the room's windows, walls and camera angle; check the furniture's color, shape and material. Inspect perspective, floor contact and shadows. Placement is a visualization, not a dimensional fit guarantee.
4. Swap the photos and repeat. The room should remain the canvas.
5. Say “Place this chair beside the window; keep the sofa.” Verify the instruction changes the placement while preserving the requested existing furniture.
6. Replace the furniture with another photo of the same dimensions. Old suggestions should clear and refresh for the replacement.
7. Save the result to Photos, then reopen it from History. Confirm the generated pixels persist.
8. Use two product listings and request “Compare their prices in a table.” Then try two document screenshots. Expect a text artifact and no rendering stage when the router chooses text.
9. Cancel during rendering, and repeat with invalid credentials or no connectivity. Expect a cancellation/error state, not a success with a permanent image spinner.

## Background acceptance checks

Open the room photo in one real app and a furniture photo or listing in the other. Use equal halves and a known orientation. Create a Shortcut with **Take Screenshot → Fuse Screens**, pass the screenshot explicitly, set **Left / Right** or **Top / Bottom**, and set the instruction to “Show this furniture in my room.” If adding **Dictate Text**, capture the screenshot before dictation and keep the Screenshot variable wired to the screenshot parameter.

Run the shortcut from a launcher supported by your simulator. Verify that Fuse does not come to the foreground, the native result card shows the generated picture, and opening Fuse later finds it in History. Repeat after a forced timeout or connectivity failure; a failed job must not be recorded as successful.

This uses a native App Intent result card. It does not add a custom overlay, global hinge listener, or a new trigger. Background image editing can exceed the system's time budget; increasing URLSession timeouts does not extend that budget. Test on the actual demo runtime. The Shortcut's returned value remains text; image-file output to later Shortcut actions is outside this change. The Safari popup also retains its existing text result presentation.

## Demo choices

For a live demo, rehearse the exact room/furniture pair, key, network and launcher. The foreground path is the reliable fallback if background image generation does not finish within the runtime budget. Keep a prior result available in History as an explicitly labeled saved example.

For a prerecorded demo, record the actual capture, request and generated result. If editing out API wait time, label the time cut. Do not present a saved image as a fresh live generation. Image output varies between runs, so judge the preservation and placement criteria rather than exact pixel equality.
