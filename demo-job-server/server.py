#!/usr/bin/env python3
"""Local, fictional employer inbox for the FUSE job-application demo.

This server never contacts an employer or another network service. Only the
fictional candidate and job defined below can be submitted.
"""

from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
from html import escape
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import logging
from pathlib import Path
import sqlite3
from urllib.parse import urlsplit
from typing import Iterator
from uuid import UUID, uuid4


JOB_ID = "bright-labs-pm-2026"
JOB_PATH = "/jobs/bright-labs-pm"
CANDIDATE_NAME = "Alex Morgan"
CANDIDATE_EMAIL = "alex.morgan@example.com"
MAX_BODY_BYTES = 256 * 1024
REQUIRED_FIELDS = {
    "applicationID", "jobID", "candidateName", "email", "resume", "coverLetter"
}

CSS = """
:root{color-scheme:light;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#172b28;background:#f7f9f6}
*{box-sizing:border-box}body{margin:0}a{color:#156a50;text-decoration:none}a:hover{text-decoration:underline}
.notice{padding:11px 24px;background:#e8edbe;color:#414b20;text-align:center;font-size:12px;letter-spacing:.02em}
header{display:flex;align-items:center;justify-content:space-between;gap:20px;max-width:1100px;margin:auto;padding:24px}
.brand{font-weight:750;font-size:23px;letter-spacing:-1px}.brand span{display:inline-grid;place-items:center;width:31px;height:31px;background:#214c3b;color:#eff9c8;border-radius:9px;margin-right:9px;font-size:22px}
nav{display:flex;gap:22px;font-size:13px}main{max-width:1100px;margin:0 auto;padding:36px 24px 64px}
.eyebrow{font-size:11px;letter-spacing:.14em;text-transform:uppercase;font-weight:750;color:#45715a}
h1{font-size:clamp(32px,6vw,58px);line-height:1.06;letter-spacing:-2px;max-width:750px;margin:18px 0 22px;font-weight:700}
h2{font-size:23px;letter-spacing:-.6px;margin-top:0}h3{font-size:15px;margin:27px 0 12px}.lead{font-size:18px;line-height:1.65;color:#526660;max-width:680px}
.chips{display:flex;gap:8px;flex-wrap:wrap;margin:24px 0 38px}.chip{padding:8px 13px;border:1px solid #d9e2da;border-radius:30px;font-size:12px;background:#fff}
.layout{display:grid;grid-template-columns:minmax(0,1fr) 300px;gap:40px}.card{background:#fff;border:1px solid #dfe7df;border-radius:20px;padding:28px;margin-bottom:20px}
.tint{background:#eaf0e6;border:0}.card p,li{font-size:15px;line-height:1.75;color:#51635b}li{padding-left:5px;margin:8px 0}ul{padding-left:18px}.small{font-size:12px!important;line-height:1.65!important;color:#67776e}
.button{display:block;text-align:center;background:#214c3b;color:#fff;padding:15px;border-radius:12px;font-size:14px;font-weight:650;margin:19px 0}
.detail{display:flex;justify-content:space-between;gap:15px;border-bottom:1px solid #d5dfd3;padding:12px 0;font-size:13px}.detail strong{text-align:right;font-weight:600}
.receipt{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap}.status{background:#e3f2e5;color:#296537;font-size:12px;font-weight:650;padding:7px 12px;border-radius:20px}
.document{white-space:pre-wrap;overflow-wrap:anywhere;background:#f7f9f6;border:1px solid #e1e8df;border-radius:12px;padding:20px;font:14px/1.7 -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#334b40}
.empty{text-align:center;padding:60px 24px}.muted{color:#63796b}.receipt-code{font-family:ui-monospace,monospace;word-break:break-all}footer{max-width:1100px;padding:0 24px 35px;margin:auto;color:#6c7c71;font-size:12px}
@media(max-width:720px){main{padding-top:16px}.layout{grid-template-columns:1fr;gap:0}.card{padding:22px}nav{gap:13px;font-size:12px}h1{letter-spacing:-1px}.lead{font-size:16px}}
"""


def page(title: str, body: str, refresh: bool = False) -> str:
    refresh_tag = '<meta http-equiv="refresh" content="10">' if refresh else ""
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">{refresh_tag}
<title>{escape(title)} · Bright Labs demo</title><style>{CSS}</style></head><body>
<div class="notice">FICTIONAL DEMO · Local test employer · No real job application is sent</div>
<header><a class="brand" href="{JOB_PATH}"><span>✳</span>bright labs</a>
<nav><a href="{JOB_PATH}">Open role</a><a href="/applications">Demo hiring inbox</a></nav></header>
<main>{body}</main><footer>Bright Labs is a fictional company created for the FUSE demo. All submissions stay on this computer.</footer>
</body></html>"""


JOB_PAGE = page("Product Manager, Merchant Growth", """
<div class="eyebrow">Build better ways to do business</div>
<h1>Product Manager,<br>Merchant Growth</h1>
<p class="lead">Help independent merchants turn their first sale into lasting growth. Own the checkout and onboarding experiences that make commerce feel effortless.</p>
<div class="chips"><span class="chip">Product</span><span class="chip">San Francisco · Hybrid</span><span class="chip">Full-time</span><span class="chip">3+ years experience</span></div>
<div class="layout"><section>
<article class="card"><h2>Small businesses. Meaningful impact.</h2>
<p>At Bright Labs, we build simple commerce tools for independent merchants. We’re looking for a thoughtful Product Manager to improve how merchants onboard, activate, and grow through a better checkout experience.</p>
<p>You’ll connect merchant research with product analytics, turn opportunities into focused experiments, and work closely with design and engineering to ship improvements.</p></article>
<article class="card"><h2>What you’ll own</h2><ul>
<li>Lead discovery with merchants and translate interviews into clear customer problems and product priorities.</li>
<li>Improve merchant onboarding and checkout conversion through measurable experiments.</li>
<li>Use SQL and product analytics to diagnose funnel drop-offs and evaluate results.</li>
<li>Partner with design, engineering, and go-to-market teams to define scope and deliver product changes.</li>
<li>Communicate trade-offs, decisions, and outcomes clearly to stakeholders.</li>
</ul></article>
<article class="card"><h2>What you’ll bring</h2><ul>
<li>3+ years of product management experience building customer-facing software.</li>
<li>Experience with customer discovery, prioritization, and cross-functional delivery.</li>
<li>Comfort working with SQL, analytics, and experimentation.</li>
<li>A track record of improving a customer journey with measurable results.</li>
<li>Clear written communication and thoughtful collaboration.</li>
</ul><h3>Nice to have, not required</h3><p>Experience with payments, merchant tools, pricing, or international product expansion.</p></article>
<article class="card"><h2>How we hire</h2><p>For this fictional demo, FUSE tailors Alex Morgan’s sample résumé, creates a short cover letter, and sends them to the local demo inbox. The inbox produces a receipt so you can verify that the application was received.</p><p class="small">Real employer submission is not supported by this demo. No account, recruiter, or external hiring platform is connected.</p></article>
</section><aside><div class="card tint"><div class="eyebrow">Role at a glance</div>
<h2 style="margin-top:15px">Make the next sale easier.</h2>
<div class="detail"><span>Team</span><strong>Merchant Growth</strong></div>
<div class="detail"><span>Location</span><strong>San Francisco</strong></div>
<div class="detail"><span>Working style</span><strong>Hybrid</strong></div>
<div class="detail"><span>Job ID</span><strong>bright-labs-pm-2026</strong></div>
<p>Open this role in FUSE and pair it with Alex Morgan’s demo résumé.</p>
<a class="button" href="/apply">Watch FUSE fill an application →</a><a href="/applications">View demo hiring inbox →</a>
<p class="small">Demo applications only. Your real résumé is not needed.</p></div></aside></div>
""")


class ValidationError(ValueError):
    pass


class ConflictingApplication(ValueError):
    pass


def canonical_uuid(value: str) -> str:
    try:
        parsed = UUID(value)
    except (ValueError, AttributeError):
        raise ValidationError("applicationID must be a UUID string") from None
    if str(parsed) != value.lower():
        raise ValidationError("applicationID must be a hyphenated UUID string")
    return str(parsed)


def validate_application(payload: object) -> dict[str, str]:
    if not isinstance(payload, dict) or set(payload) != REQUIRED_FIELDS:
        raise ValidationError("Provide exactly applicationID, jobID, candidateName, email, resume, and coverLetter")
    if not all(isinstance(value, str) for value in payload.values()):
        raise ValidationError("All application fields must be strings")
    result = dict(payload)
    result["applicationID"] = canonical_uuid(result["applicationID"])
    if result["jobID"] != JOB_ID:
        raise ValidationError("Only the fictional Bright Labs demo job is supported")
    if result["candidateName"] != CANDIDATE_NAME or result["email"] != CANDIDATE_EMAIL:
        raise ValidationError("Only fictional candidate Alex Morgan (alex.morgan@example.com) is accepted")
    for field in ("resume", "coverLetter"):
        value = result[field]
        if not value.strip():
            raise ValidationError(f"{field} must not be empty")
        if "\x00" in value:
            raise ValidationError(f"{field} must not contain null characters")
        if len(value) > 100_000:
            raise ValidationError(f"{field} must not exceed 100000 characters")
    return result


class ApplicationStore:
    def __init__(self, database: Path):
        self.database = database
        database.parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as connection:
            connection.execute("""CREATE TABLE IF NOT EXISTS applications (
                application_id TEXT PRIMARY KEY,
                payload TEXT NOT NULL,
                receipt TEXT NOT NULL,
                received_at TEXT NOT NULL
            )""")

    @contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        connection = sqlite3.connect(self.database, timeout=10)
        try:
            with connection:
                yield connection
        finally:
            connection.close()

    def submit(self, payload: dict[str, str]) -> tuple[dict, bool]:
        encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        with self.connect() as connection:
            # Serialize competing inserts so retries cannot create duplicate receipts.
            connection.execute("BEGIN IMMEDIATE")
            previous = connection.execute(
                "SELECT payload, receipt FROM applications WHERE application_id = ?",
                (payload["applicationID"],),
            ).fetchone()
            if previous:
                if previous[0] != encoded:
                    raise ConflictingApplication("This applicationID was already used for a different application")
                return json.loads(previous[1]), False
            received_at = datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
            receipt = {
                "applicationID": payload["applicationID"],
                "receiptID": "BL-DEMO-" + str(uuid4()),
                "jobID": JOB_ID,
                "candidateName": CANDIDATE_NAME,
                "receivedAt": received_at,
                "status": "received",
                "destination": "Bright Labs demo inbox",
            }
            connection.execute(
                "INSERT INTO applications VALUES (?, ?, ?, ?)",
                (payload["applicationID"], encoded, json.dumps(receipt), received_at),
            )
            return receipt, True

    def receipt(self, application_id: str) -> dict | None:
        with self.connect() as connection:
            row = connection.execute(
                "SELECT receipt FROM applications WHERE application_id = ?", (application_id,)
            ).fetchone()
        return json.loads(row[0]) if row else None

    def applications(self) -> list[tuple[dict, dict]]:
        with self.connect() as connection:
            rows = connection.execute(
                "SELECT payload, receipt FROM applications ORDER BY received_at DESC, application_id"
            ).fetchall()
        return [(json.loads(payload), json.loads(receipt)) for payload, receipt in rows]


def inbox_page(store: ApplicationStore) -> str:
    applications = store.applications()
    cards = []
    for application, receipt in applications:
        cards.append(f"""<article class="card">
<div class="receipt"><div><div class="eyebrow">Product Manager · Merchant Growth</div>
<h2 style="margin:12px 0 5px">{escape(application['candidateName'])}</h2>
<p class="small">{escape(application['email'])} · {escape(receipt['receivedAt'])}</p></div>
<span class="status">✓ Application received</span></div>
<p class="small receipt-code">Receipt {escape(receipt['receiptID'])}<br>Application {escape(receipt['applicationID'])}</p>
<h3>Tailored résumé</h3><div class="document">{escape(application['resume'])}</div>
<h3>Cover letter</h3><div class="document">{escape(application['coverLetter'])}</div></article>""")
    content = "".join(cards) or '<div class="card empty"><h2>Your demo inbox is ready.</h2><p>Submit the fictional Alex Morgan application from FUSE.<br>The received résumé, cover letter, and receipt will appear here.</p></div>'
    return page("Demo hiring inbox", f"""<div class="eyebrow">Employer view · local only</div>
<h1>Applications, received.</h1><p class="lead">{len(applications)} demo application{'s' if len(applications) != 1 else ''} received. A real local submission, with a verifiable receipt.</p>
<p class="small">This page refreshes every 10 seconds. It never sends a real job application.</p>{content}""", refresh=True)


def reject_duplicate_keys(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValidationError("Duplicate JSON fields are not accepted")
        result[key] = value
    return result


class DemoServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], database: Path):
        self.store = ApplicationStore(database)
        super().__init__(address, DemoHandler)


class DemoHandler(BaseHTTPRequestHandler):
    server: DemoServer
    server_version = "FuseDemo/1.0"

    def setup(self) -> None:
        super().setup()
        self.connection.settimeout(10)

    def log_message(self, fmt: str, *args: object) -> None:
        logging.info("%s %s", self.address_string(), fmt % args)

    def respond(self, status: int, body: str | dict, content_type: str = "application/json") -> None:
        data = (json.dumps(body) if isinstance(body, dict) else body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type + "; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'none'; script-src 'self'; connect-src 'self'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
        self.end_headers()
        self.wfile.write(data)

    def local_request(self) -> bool:
        port = self.server.server_address[1]
        valid_hosts = {f"127.0.0.1:{port}", f"localhost:{port}"}
        if self.headers.get("Host", "").lower() not in valid_hosts:
            self.respond(403, {"error": "Only local demo requests are accepted"})
            return False
        origin = self.headers.get("Origin")
        if origin and origin.lower() not in {f"http://{host}" for host in valid_hosts}:
            self.respond(403, {"error": "Cross-origin demo submissions are not accepted"})
            return False
        return True

    def do_GET(self) -> None:
        if not self.local_request():
            return
        path = urlsplit(self.path).path
        if path in ("/", JOB_PATH):
            self.respond(200, JOB_PAGE, "text/html")
        elif path == "/apply":
            self.respond(200, page("Apply for Merchant Growth", (Path(__file__).parent / "application-form.html").read_text()), "text/html")
        elif path == "/application-form.js":
            self.respond(200, (Path(__file__).parent / "application-form.js").read_text(), "text/javascript")
        elif path == "/api/demo/prepared-application":
            applications = self.server.store.applications()
            if not applications:
                self.respond(404, {"error": "First prepare and submit the fictional application in FUSE."})
            else:
                payload, _ = applications[0]
                self.respond(200, {key: value for key, value in payload.items() if key != "applicationID"})
        elif path == "/applications":
            self.respond(200, inbox_page(self.server.store), "text/html")
        elif path.startswith("/api/demo/applications/"):
            try:
                application_id = canonical_uuid(path.removeprefix("/api/demo/applications/"))
            except ValidationError as error:
                self.respond(400, {"error": str(error)})
                return
            receipt = self.server.store.receipt(application_id)
            self.respond(200 if receipt else 404, receipt or {"error": "Application not found"})
        else:
            self.respond(404, {"error": "Not found"})

    def do_POST(self) -> None:
        if not self.local_request():
            return
        if urlsplit(self.path).path != "/api/demo/applications":
            self.respond(404, {"error": "Not found"})
            return
        if self.headers.get("Transfer-Encoding"):
            self.respond(400, {"error": "Chunked request bodies are not accepted"})
            return
        if self.headers.get_content_type() != "application/json":
            self.respond(415, {"error": "Content-Type must be application/json"})
            return
        lengths = self.headers.get_all("Content-Length", [])
        if not lengths:
            self.respond(411, {"error": "Content-Length is required"})
            return
        if len(lengths) != 1 or not lengths[0].isdigit():
            self.respond(400, {"error": "Invalid Content-Length"})
            return
        length = int(lengths[0])
        if length > MAX_BODY_BYTES:
            self.respond(413, {"error": "Application must not exceed 256 KB"})
            return
        try:
            raw = self.rfile.read(length)
            if len(raw) != length:
                raise ValidationError("Incomplete request body")
            payload = json.loads(raw.decode("utf-8"), object_pairs_hook=reject_duplicate_keys)
            validated = validate_application(payload)
            receipt, created = self.server.store.submit(validated)
        except (UnicodeDecodeError, json.JSONDecodeError, RecursionError):
            self.respond(400, {"error": "Provide a valid UTF-8 JSON object"})
        except ValidationError as error:
            self.respond(400, {"error": str(error)})
        except ConflictingApplication as error:
            self.respond(409, {"error": str(error)})
        except ValueError:
            self.respond(400, {"error": "Provide a valid UTF-8 JSON object"})
        except (TimeoutError, OSError, sqlite3.Error):
            logging.exception("Local application could not be saved")
            self.respond(503, {"error": "The local demo inbox is unavailable; retry with the same applicationID"})
        else:
            self.respond(201 if created else 200, receipt)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8777)
    parser.add_argument("--database", type=Path, default=Path(__file__).parent / ".local" / "applications.sqlite3")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    server = DemoServer(("127.0.0.1", args.port), args.database)
    logging.info("Fictional job: http://127.0.0.1:%s%s", args.port, JOB_PATH)
    logging.info("Local employer inbox: http://127.0.0.1:%s/applications", args.port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
