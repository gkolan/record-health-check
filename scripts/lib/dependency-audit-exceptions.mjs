// Advisories with no published fix, reachable only through development tooling
// of the root project. Production audits never consult this list. Each entry
// expires so the gate fails again and forces a fresh review.
export const DEVELOPMENT_AUDIT_EXCEPTIONS = [
  {
    id: "GHSA-vfj7-8cjw-p6xm",
    package: "braces",
    expires: "2026-11-06",
    reason:
      "braces 3.0.3 is the latest release; reached only through Jest (sfdx-lwc-jest > micromatch)."
  },
  {
    id: "GHSA-hp3w-g68c-fv3c",
    package: "sprintf-js",
    expires: "2026-11-06",
    reason:
      "sprintf-js 1.1.3 is the latest release; reached only through Istanbul coverage (argparse)."
  }
];

const ADVISORY_ID = /GHSA-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}/;

/**
 * Returns the advisories in an `npm audit --json` report that are not covered by
 * an unexpired exception. Throws when the report cannot be read, so a broken or
 * empty report can never pass.
 */
export function unexcusedAdvisories(
  reportText,
  today,
  exceptions = DEVELOPMENT_AUDIT_EXCEPTIONS
) {
  const report = JSON.parse(reportText);
  if (!report || typeof report.vulnerabilities !== "object") {
    throw new Error("npm audit did not return a vulnerability report.");
  }
  const active = new Map(
    exceptions
      .filter((exception) => today <= exception.expires)
      .map((exception) => [exception.id, exception.package])
  );
  const unexcused = new Set();
  for (const [name, vulnerability] of Object.entries(report.vulnerabilities)) {
    for (const via of vulnerability.via ?? []) {
      if (typeof via !== "object") continue; // inherited from another entry
      const id = String(via.url ?? "").match(ADVISORY_ID)?.[0];
      if (!id || active.get(id) !== (via.name ?? name)) {
        unexcused.add(`${via.name ?? name} ${id ?? via.title ?? "advisory"}`);
      }
    }
  }
  return [...unexcused].sort();
}
