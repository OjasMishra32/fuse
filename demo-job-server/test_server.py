"""Integration checks against a real HTTP server and temporary SQLite database."""

from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack, contextmanager
import http.client
import json
from pathlib import Path
import tempfile
import threading
import unittest
from uuid import uuid4

from server import DemoServer, JOB_ID, JOB_PATH, MAX_BODY_BYTES


@contextmanager
def running_server(database: Path):
    server = DemoServer(("127.0.0.1", 0), database)
    thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.02}, daemon=True)
    thread.start()
    try:
        yield server.server_address[1]
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


class DemoHTTPTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.database = Path(self.temporary.name) / "applications.sqlite3"
        stack = ExitStack()
        self.addCleanup(stack.close)
        self.port = stack.enter_context(running_server(self.database))
        self.payload = {
            "applicationID": str(uuid4()),
            "jobID": JOB_ID,
            "candidateName": "Alex Morgan",
            "email": "alex.morgan@example.com",
            "resume": "Alex Morgan\nProduct Manager · 4 years\nImproved checkout conversion by 12%.",
            "coverLetter": "Dear Bright Labs team,\nMy merchant discovery and checkout experience match this role.",
        }

    def request(self, method, path, payload=None, headers=None, raw=None, port=None):
        connection = http.client.HTTPConnection("127.0.0.1", port or self.port, timeout=3)
        body = raw if raw is not None else json.dumps(payload).encode() if payload is not None else None
        request_headers = {"Content-Type": "application/json"} if body is not None else {}
        request_headers.update(headers or {})
        try:
            connection.request(method, path, body, request_headers)
            response = connection.getresponse()
            text = response.read().decode()
            value = json.loads(text) if "application/json" in response.getheader("Content-Type", "") else text
            return response.status, value, dict(response.getheaders())
        finally:
            connection.close()

    def submit(self, payload=None, **kwargs):
        return self.request("POST", "/api/demo/applications", self.payload if payload is None else payload, **kwargs)

    def test_job_page_is_explicitly_fictional_and_contains_requirements(self):
        status, page, headers = self.request("GET", JOB_PATH)
        self.assertEqual(status, 200)
        for text in ("FICTIONAL DEMO", "Product Manager", "Merchant Growth", "SQL", "3+ years", "experiments", "checkout", "No real job application is sent"):
            self.assertIn(text, page)
        self.assertEqual(headers["Cache-Control"], "no-store")

    def test_submission_returns_receipt_and_is_retrievable(self):
        status, receipt, _ = self.submit()
        self.assertEqual(status, 201)
        self.assertEqual(set(receipt), {"applicationID", "receiptID", "jobID", "candidateName", "receivedAt", "status", "destination"})
        self.assertEqual(receipt["applicationID"], self.payload["applicationID"])
        self.assertEqual(receipt["status"], "received")
        self.assertEqual(receipt["destination"], "Bright Labs demo inbox")
        self.assertTrue(receipt["receivedAt"].endswith("Z"))
        status, fetched, _ = self.request("GET", "/api/demo/applications/" + self.payload["applicationID"])
        self.assertEqual((status, fetched), (200, receipt))

    def test_identical_retry_has_same_receipt_and_only_one_row(self):
        _, original, _ = self.submit()
        status, retried, _ = self.submit(dict(reversed(list(self.payload.items()))))
        self.assertEqual(status, 200)
        self.assertEqual(retried, original)
        _, inbox, _ = self.request("GET", "/applications")
        self.assertEqual(inbox.count('class="status"'), 1)

    def test_concurrent_retries_have_exactly_one_created_application(self):
        with ThreadPoolExecutor(max_workers=6) as executor:
            responses = list(executor.map(lambda _: self.submit(), range(6)))
        self.assertEqual([result[0] for result in responses].count(201), 1)
        self.assertEqual([result[0] for result in responses].count(200), 5)
        self.assertEqual(len({result[1]["receiptID"] for result in responses}), 1)

    def test_reused_id_with_changed_payload_returns_conflict(self):
        _, receipt, _ = self.submit()
        changed = dict(self.payload, resume="Different résumé")
        status, error, _ = self.submit(changed)
        self.assertEqual(status, 409)
        self.assertIn("different application", error["error"])
        _, persisted, _ = self.request("GET", "/api/demo/applications/" + self.payload["applicationID"])
        self.assertEqual(persisted, receipt)

    def test_receipt_survives_server_restart(self):
        _, receipt, _ = self.submit()
        # A separate server process instance reopens the same on-disk database.
        with running_server(self.database) as reopened_port:
            status, persisted, _ = self.request("GET", "/api/demo/applications/" + self.payload["applicationID"], port=reopened_port)
            self.assertEqual((status, persisted), (200, receipt))
            status, retried, _ = self.submit(port=reopened_port)
            self.assertEqual((status, retried), (200, receipt))

    def test_real_candidate_name_or_email_is_rejected(self):
        for changed in (dict(self.payload, candidateName="Someone Else"), dict(self.payload, email="actual@example.org")):
            with self.subTest(changed=changed):
                status, body, _ = self.submit(changed)
                self.assertEqual(status, 400)
                self.assertIn("Only fictional candidate", body["error"])

    def test_wrong_job_is_rejected(self):
        status, body, _ = self.submit(dict(self.payload, jobID="a-real-employer-job"))
        self.assertEqual(status, 400)
        self.assertIn("fictional", body["error"])

    def test_unknown_missing_and_non_string_fields_are_rejected(self):
        missing = dict(self.payload)
        del missing["resume"]
        for payload in (missing, dict(self.payload, phone="555"), dict(self.payload, resume=123), []):
            with self.subTest(payload=payload):
                self.assertEqual(self.submit(payload)[0], 400)

    def test_empty_resume_or_cover_letter_is_rejected(self):
        for field in ("resume", "coverLetter"):
            with self.subTest(field=field):
                self.assertEqual(self.submit(dict(self.payload, **{field: "  \n"}))[0], 400)

    def test_invalid_application_uuid_is_rejected(self):
        for value in ("not-an-id", uuid4().hex, "", "../test"):
            with self.subTest(value=value):
                self.assertEqual(self.submit(dict(self.payload, applicationID=value))[0], 400)

    def test_unknown_application_is_404(self):
        self.assertEqual(self.request("GET", "/api/demo/applications/" + str(uuid4()))[0], 404)

    def test_employer_inbox_contains_escaped_documents(self):
        payload = dict(self.payload, resume='<script>alert("resume")</script>\nMerchant impact', coverLetter="<img src=x onerror=alert(1)> & thank you")
        self.submit(payload)
        status, inbox, _ = self.request("GET", "/applications")
        self.assertEqual(status, 200)
        self.assertIn("&lt;script&gt;", inbox)
        self.assertIn("&lt;img src=x onerror=alert(1)&gt; &amp; thank you", inbox)
        self.assertNotIn('<script>alert("resume")</script>', inbox)
        self.assertIn("Merchant impact", inbox)

    def test_empty_inbox_is_helpful(self):
        status, inbox, _ = self.request("GET", "/applications")
        self.assertEqual(status, 200)
        self.assertIn("Your demo inbox is ready", inbox)
        self.assertIn("0 demo applications", inbox)

    def test_oversized_body_is_rejected_before_read(self):
        status, error, _ = self.submit(headers={"Content-Length": str(MAX_BODY_BYTES + 1)})
        self.assertEqual(status, 413)
        self.assertIn("256 KB", error["error"])

    def test_bad_json_utf8_and_duplicate_fields_are_rejected(self):
        for raw in (b"{", b"\xff", b'{"applicationID":"a","applicationID":"b"}'):
            with self.subTest(raw=raw):
                self.assertEqual(self.request("POST", "/api/demo/applications", raw=raw)[0], 400)

    def test_non_json_and_chunked_requests_are_rejected(self):
        self.assertEqual(self.submit(headers={"Content-Type": "text/plain"})[0], 415)
        self.assertEqual(self.submit(headers={"Transfer-Encoding": "chunked"})[0], 400)

    def test_browser_cross_origin_and_non_local_hosts_are_rejected(self):
        self.assertEqual(self.submit(headers={"Origin": "https://unrelated.example"})[0], 403)
        self.assertEqual(self.submit(headers={"Host": "unrelated.example"})[0], 403)
        self.assertEqual(self.submit(headers={"Origin": f"http://127.0.0.1:{self.port}"})[0], 201)


if __name__ == "__main__":
    unittest.main(verbosity=2)
