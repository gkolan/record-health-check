import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

// Cover package metadata, test overlays, and subscriber/namespace fixtures.
// This identifies local input, not what is deployed in a Salesforce org.
const sourcePaths = [
  "packages/record-health-check/force-app",
  "packages/record-health-check/integration-tests/main",
  "packages/record-health-check/sfdx-project.json",
  "subscriber-app/main",
  "namespace-fixture/force-app",
  "config/apex-test-overlays.json"
];

export function apexSourceSnapshot(root) {
  const files = [];
  function visit(relative) {
    const absolute = join(root, relative);
    if (!existsSync(absolute)) return;
    if (statSync(absolute).isDirectory()) {
      for (const name of readdirSync(absolute)) visit(`${relative}/${name}`);
    } else {
      files.push(relative);
    }
  }
  for (const relative of sourcePaths) visit(relative);
  const hash = createHash("sha256");
  for (const relative of files.sort()) {
    hash.update(relative).update("\0");
    hash.update(
      createHash("sha256")
        .update(readFileSync(join(root, relative)))
        .digest()
    );
  }
  return hash.digest("hex");
}

export function apexEvidenceStatus(apex, currentSnapshot) {
  const recorded = apex.sourceSnapshotSha256;
  if (recorded === null) return "historical-unbound";
  if (typeof recorded !== "string" || !/^[a-f0-9]{64}$/.test(recorded)) {
    throw new Error(
      "Apex sourceSnapshotSha256 must be a SHA-256 digest or explicit null for historical evidence."
    );
  }
  return recorded === currentSnapshot
    ? "source-matched"
    : "historical-source-mismatch";
}
