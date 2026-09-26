# Apply with a fold — team integration

This is the **job-application use case** inside the existing FUSE application. It starts from shared `origin/main` commit `355666e` on branch `codex/job-application-demo`. Other recipes, image workflows, Safari extensions, and shared result types remain on the team's implementation. The earlier local broad redesign is not included.

## Demo

1. Start the fictional employer: `python3 demo-job-server/server.py`.
2. Build/run the existing **Fuse** scheme on iPhone Duo using Xcode 27.1. Configure the existing OpenAI key in Settings if needed.
3. Open Scenarios and choose **Apply with a fold**, or open `fuse://demo?id=job-application`.
4. The left inner pane loads the actual local Bright Labs job page in FUSE's browser surface; the right inner pane holds Alex Morgan's fictional résumé in FUSE's Notes surface.
5. The action strip discloses the destination and AI processing. Fully close the phone, or use **Apply to demo job**. **Preview closed** explicitly rehearses the compact outer-screen presentation when the simulator does not deliver a physical fold/display transition.
6. AI tailors evidence-backed passages and writes a cover letter. FUSE submits the documents to the local employer service. Only a valid server receipt produces **Application received**.
7. Reopen to inspect the original, submitted résumé, cover letter, and qualifications not established by the source. Open `http://127.0.0.1:8777/applications` to show the employer's independently persisted submission.

## What this demonstrates

- A real AI request against a fictional applicant and job.
- A real HTTP submission and durable employer receipt, within a local demo environment.
- Repeated fold events do not trigger duplicate submissions. Network retries reuse the application ID and prepared payload.
- New employers, application questions, authentication, legal declarations and real submissions are outside this demo.

## Display and platform boundary

Open: job on inner-left, résumé on inner-right; outer display unused. Closed: the intended outer presentation shows progress and receipt, subject to the tested simulator lifecycle. Reopened: original and tailored documents use the inner area; outer display unused. Layout uses scene geometry and division regions; hinge state is an action trigger.

These are browser and Notes **surfaces inside FUSE**, not embedded copies of the system Safari and Apple Notes apps. This use case cannot independently read another app's private document or guarantee background hinge events. The team's external capture mechanisms can later supply job/résumé inputs through an explicit adapter. Do not describe the rehearsal button as a physical fold, or a local receipt as a real employer application.

## Code boundaries for merging

- Feature: `Fuse/Features/JobApplication/`.
- Employer: `demo-job-server/` (standard library only).
- Shared integration: small additions in AppModel, DemoScenarios, RootView; generated Xcode project includes the new files.
- Existing OpenAIClient is reused. Shared Prompts/FuseResult/Surface contracts are not changed.
- Automatic public result upload and the floating orb are not used by the job submission route.

Local secrets, the employer SQLite database, and generated test receipts must not be committed.

## Verified in this checkout

- Final app build succeeded with the installed iOS 27.1 SDK. 44 native tests passed (29 existing team tests, 3 fold/integration tests, 12 job-session tests). The 18 employer HTTP/SQLite tests also passed.
- Live simulator run: selected the prepared job/résumé, invoked the labeled **Preview closed** action, made a real OpenAI request, submitted the tailored documents by HTTP, and verified the matching receipt in the phone UI and employer inbox. Receipt: `BL-DEMO-71f59d47-fb53-4014-82f6-d0de3059fa71`. Application: `125af51b-88ee-4681-8bb6-08c3c78c90c9`.
- Inspected the actual AI output: employer, role, dates, 12% metric and 20 interviews were preserved. Rewriting is limited to exact allowed source passages, with numeric checks; this is not a universal semantic guarantee against every unsupported AI claim.
- Inner review and compact receipt presentation were inspected. The app retains the receipt after relaunch; **New demo application** explicitly clears the local session for another rehearsal, without deleting the employer's prior receipt.
- Bitrig's host close button selected Closed, but FUSE continued reporting 180° Open. No physical hinge callback or automatic outer-display handoff was verified. The labeled simulator preview is the demonstrated trigger; do not claim physical background folding was validated.
- No real employer, external application platform, or user's personal résumé was used. The local demo server must remain running on the simulator's Mac; port 8777 is not a deployed public backend.

## Visible application-form replay

After one successful native application, open http://127.0.0.1:8777/apply in Chrome. Select **Watch FUSE fill the form** to animate contact details, the saved AI-tailored résumé, and cover letter into a real local employer form. Select **Submit demo application**. Success appears only after POST saves the application and a separate GET verifies its receipt. Reload/retry retains the same application identifier to avoid duplicates.

This is an explicitly labeled browser replay of the previously generated fictional documents, not new AI generation or a verified fold-triggered form animation. Chrome was tested; the Codex in-app browser did not execute the fill interaction during testing. The native app now separately shows its own four-field application card while filling. Its session completes that stage before submitting; the browser replay is optional.

## Integration validation

Rebased onto team main `631ba58`, retaining its image-fusion and scenario updates. The job-specific close guard is routed before the generic fold handler, so unprepared closes and closed launches do not submit. The shared AI client now includes image-related errors; the job flow handles those without exposing raw service responses. Physical close-to-cover behavior still requires simulator verification; the explicit preview remains available.

## Native application UI update

The completed native screen now leads with **Application filled. Résumé customized.** and populated name, email, customized résumé, and cover-letter fields. Documents expand inline; the local delivery receipt is secondary. Complete sample job/résumé pairs activate this native route in either pane order, including manually staged pairs. Partial résumés and unrelated URLs are not silently submitted.

Validation: 66 native tests pass, including both pane orders, incomplete-pair rejection, and recognition when the résumé body changes without its headline changing. Installed the updated `local.fuse.review` build in Bitrig. A fresh application and local delivery receipt were observed in the native UI. Automated host fold controls intermittently change their selected state without delivering the corresponding hinge update; physical gesture validation remains distinct from the working in-app preview.
