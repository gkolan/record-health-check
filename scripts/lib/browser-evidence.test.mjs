import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  browserEvidencePaths,
  assertBrowserReport,
  redactBrowserEvidence,
  redactBrowserEvidenceDirectory,
  browserEvidenceHtml
} from "./browser-evidence.mjs";

const REPORT_ERROR = /Browser evidence must contain passing tests/;

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
    assert.throws(
      () =>
        assertBrowserReport({
          ...report,
          stats: { ...report.stats, [field]: 1 }
        }),
      REPORT_ERROR
    );
  }
  assert.throws(
    () =>
      assertBrowserReport({
        ...report,
        stats: { ...report.stats, expected: 0 }
      }),
    REPORT_ERROR
  );
  assert.throws(
    () =>
      assertBrowserReport({ ...report, errors: [{ message: "setup failed" }] }),
    REPORT_ERROR
  );
  assert.throws(() => assertBrowserReport({}), REPORT_ERROR);
});

test("redacts Salesforce-generated content-door session and encrypted login parameters", () => {
  const raw =
    "https://example.invalid/secur/contentDoor?sid=new-session-token&lm=encrypted-login&skipRedirect=1";
  const result = redactBrowserEvidence(raw, {});
  assert.ok(!result.includes("new-session-token"));
  assert.ok(!result.includes("encrypted-login"));
  assert.ok(result.includes("skipRedirect=1"));
});

test("redacts retained failure-context Markdown and leaves clean context unchanged", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-evidence-"));
  const nested = path.join(directory, "url-story-chromium");
  fs.mkdirSync(nested);
  const leaked = path.join(nested, "error-context.md");
  const clean = path.join(directory, "clean-context.md");
  const password = "not-a-real-password";
  fs.writeFileSync(
    leaked,
    `- Page URL: https://example.invalid/secur/contentDoor?sid=live-session&lm=login\n- typed ${password}\n`
  );
  fs.writeFileSync(clean, "- Page URL: https://example.invalid/home\n");

  redactBrowserEvidenceDirectory(directory, {
    RHC_RESTRICTED_NEW_PASSWORD: password
  });

  const redacted = fs.readFileSync(leaked, "utf8");
  for (const secret of ["live-session", "=login", password]) {
    assert.ok(!redacted.includes(secret), `${secret} must be redacted`);
  }
  assert.equal(
    fs.readFileSync(clean, "utf8"),
    "- Page URL: https://example.invalid/home\n"
  );
});

test("every browser runner that retains Playwright output redacts its Markdown", () => {
  const releaseDirectory = path.resolve(import.meta.dirname, "../release");
  const runners = fs
    .readdirSync(releaseDirectory)
    .filter((name) => name.endsWith(".mjs"))
    .filter((name) =>
      fs
        .readFileSync(path.join(releaseDirectory, name), "utf8")
        .includes("RHC_BROWSER_OUTPUT:")
    );
  assert.deepEqual(runners.sort(), [
    "run_salesforce_browser_gate.mjs",
    "run_url_story_browser.mjs"
  ]);
  for (const runner of runners) {
    assert.match(
      fs.readFileSync(path.join(releaseDirectory, runner), "utf8"),
      /redactBrowserEvidenceDirectory\(evidence\.output, environment\)/,
      `${runner} must redact failure-context Markdown before retaining evidence`
    );
  }
});
