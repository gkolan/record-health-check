import assert from "node:assert/strict";
import test from "node:test";
import {
  browserEvidencePaths,
  assertBrowserReport,
  redactBrowserEvidence,
  browserEvidenceHtml
} from "./browser-evidence.mjs";

test("browser artifacts redact login URLs, sessions, and passwords before publication", () => {
  const session = "test-session/not-real";
  const url = `https://example.invalid/secur/frontdoor.jsp?sid=${encodeURIComponent(session)}`;
  const password = 'not-a-real-"password';
  const raw = JSON.stringify({
    url,
    encoded: encodeURIComponent(url),
    session,
    encodedSession: encodeURIComponent(session),
    password,
    error: "<script>alert(1)</script>"
  });
  const sanitized = redactBrowserEvidence(raw, {
    RHC_BROWSER_URL: url,
    RHC_RESTRICTED_NEW_PASSWORD: password
  });
  const parsed = JSON.parse(sanitized);
  for (const key of [
    "url",
    "encoded",
    "session",
    "encodedSession",
    "password"
  ]) {
    assert.equal(parsed[key], "[REDACTED]");
  }
  assert.ok(!browserEvidenceHtml(sanitized).includes("<script>"));
});

test("each browser and scenario retains separate evidence", () => {
  const paths = [];
  for (const browser of ["chromium", "firefox"]) {
    for (const spec of [
      "release-matrix",
      "app-builder",
      "restricted-persona"
    ]) {
      paths.push(
        browserEvidencePaths(
          "lws-123",
          browser,
          `tests/browser/${spec}.spec.mjs`
        ).output
      );
    }
  }
  assert.equal(new Set(paths).size, 6);
  assert.throws(() =>
    browserEvidencePaths("../escape", "chromium", "a.spec.mjs")
  );
});

test("browser evidence rejects empty, skipped, flaky, and failed runs", () => {
  const report = {
    stats: { expected: 1, unexpected: 0, skipped: 0, flaky: 0 },
    errors: []
  };
  assert.deepEqual(assertBrowserReport(report), { passed: 1 });
  for (const field of ["unexpected", "skipped", "flaky"]) {
    assert.throws(() =>
      assertBrowserReport({ ...report, stats: { ...report.stats, [field]: 1 } })
    );
  }
  assert.throws(() =>
    assertBrowserReport({ ...report, stats: { ...report.stats, expected: 0 } })
  );
  assert.throws(() =>
    assertBrowserReport({ ...report, errors: [{ message: "setup failed" }] })
  );
  assert.throws(() => assertBrowserReport({}));
});
