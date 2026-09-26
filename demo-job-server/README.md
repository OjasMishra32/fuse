# FUSE job-application demo employer

A fictional **Bright Labs** job posting and a real, local employer inbox. FUSE can submit a tailored sample résumé and cover letter, receive a durable receipt, and show the same submission in the employer view. Nothing is sent to a real employer or a third-party hiring service.

## Run

Requires Python 3.9 or newer; no packages or API keys are needed.

```sh
cd demo-job-server
python3 server.py
```

- Job posting: <http://127.0.0.1:8777/jobs/bright-labs-pm>
- Employer inbox: <http://127.0.0.1:8777/applications>
- Default database: `demo-job-server/.local/applications.sqlite3` (ignored by Git)

The server binds only to `127.0.0.1`. The iOS simulator on the same Mac can reach this address; a physical phone cannot use this address to reach the Mac. The inbox refreshes every ten seconds. Keep the server running during the demo.

Use `python3 server.py --port 8778 --database /tmp/fuse-demo.sqlite3` for an isolated run. To reset the default demo, stop the server, remove `.local/applications.sqlite3`, and restart it. Removing the file permanently clears the local demo applications.

## Submission contract

`POST /api/demo/applications` with `Content-Type: application/json` and a JSON body:

```json
{
  "applicationID": "e9e80462-2e4d-4e7a-97d3-7852cf20e780",
  "jobID": "bright-labs-pm-2026",
  "candidateName": "Alex Morgan",
  "email": "alex.morgan@example.com",
  "resume": "The tailored fictional résumé…",
  "coverLetter": "The fictional application cover letter…"
}
```

Only those six fields are accepted, all as strings. The job, candidate name, and email must exactly match the values above. Résumé and cover letter must each be nonempty and at most 100,000 characters. The entire body must not exceed 256 KiB. This guardrail is deliberate: the demo cannot submit a real candidate to a real job.

A new application returns HTTP **201**:

```json
{
  "applicationID": "e9e80462-2e4d-4e7a-97d3-7852cf20e780",
  "receiptID": "BL-DEMO-<unique UUID>",
  "jobID": "bright-labs-pm-2026",
  "candidateName": "Alex Morgan",
  "receivedAt": "2026-09-26T15:04:05.123Z",
  "status": "received",
  "destination": "Bright Labs demo inbox"
}
```

Save the `applicationID` **before** starting submission. Retry the exact same payload and ID after a timeout or interruption: identical retries return HTTP **200** with the original receipt. Reusing that ID with different content returns **409** without replacing the saved application. Concurrent retries also produce only one application and receipt.

`GET /api/demo/applications/{applicationID}` returns the saved receipt, or **404** if unknown. This lets FUSE reconcile an ambiguous connection failure before claiming submission failed. The receipt is returned only after SQLite commits the application. The employer inbox displays the persisted résumé and cover letter as escaped text.

Other responses: **400** invalid input, **403** nonlocal Host or cross-origin request, **411** missing content length, **413** oversized body, **415** non-JSON body, **503** local storage temporarily unavailable.

## Test

```sh
cd demo-job-server
python3 -m unittest -v test_server.py
```

The integration suite starts actual HTTP servers on ephemeral loopback ports with temporary SQLite databases. It checks receipts, durable storage, retry/concurrent idempotence, conflict handling, strict demo-only validation, body limits, malformed inputs, browser-origin checks, and safe rendering of résumé/cover-letter text. It does not contact any external service.

This server validates only the fictional employer submission path. It does not establish access to Safari or Notes, background fold detection, AI accuracy, or physical display transitions; those must be verified separately in the native app and simulator.
