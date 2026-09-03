import path from "node:path";

// Browser login URLs and generated scratch-user passwords must never enter
// uploaded reports or console logs. Binary authentication captures are disabled.
export function redactBrowserEvidence(text, environment) {
  const values = Object.entries(environment)
    .filter(
      ([key, value]) =>
        key.startsWith("RHC_") && /URL|PASSWORD/.test(key) && value
    )
    .flatMap(([, value]) => {
      let sid = "";
      try {
        sid = new URL(value).searchParams.get("sid") || "";
      } catch {
        /* Password, not URL. */
      }
      return [value, sid].filter(Boolean);
    });
  const secrets = [
    ...new Set(
      values.flatMap((value) => [
        value,
        encodeURIComponent(value),
        JSON.stringify(value).slice(1, -1)
      ])
    )
  ].sort((a, b) => b.length - a.length);
  let redacted = String(text);
  for (const secret of secrets)
    redacted = redacted.split(secret).join("[REDACTED]");
  return redacted;
}

export function browserEvidenceHtml(redactedJson) {
  const escaped = redactedJson
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
  return `<!doctype html><meta charset="utf-8"><title>Sanitized browser evidence</title><h1>Browser result</h1><p>Authentication captures are intentionally disabled.</p><pre>${escaped}</pre>`;
}

export function browserEvidencePaths(runId, browser, spec) {
  const scenario = path.basename(spec, ".spec.mjs");
  for (const value of [runId, browser, scenario]) {
    if (!/^[a-z0-9-]+$/i.test(value))
      throw new Error("Invalid browser evidence identity.");
  }
  const identity = `${runId}/${browser}/${scenario}`;
  return {
    output: `test-results/browser/${identity}`,
    html: `playwright-report/${identity}`,
    json: `test-results/browser/${identity}/result.json`
  };
}

export function assertBrowserReport(report) {
  const stats = report?.stats;
  if (
    !stats ||
    !Number.isInteger(stats.expected) ||
    stats.expected < 1 ||
    stats.unexpected !== 0 ||
    stats.skipped !== 0 ||
    stats.flaky !== 0 ||
    !Array.isArray(report.errors) ||
    report.errors.length !== 0
  ) {
    throw new Error(
      "Browser evidence must contain passing tests, no skips, failures, errors, or flaky retries."
    );
  }
  return { passed: stats.expected };
}
