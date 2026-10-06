import fs from "node:fs";
import path from "node:path";

/** Restricts reuse to retained release pairs or the existing upgrade-only path. */
export function assertReuseOptions({
  reuseExistingOrg,
  upgradeOnly,
  releasePair,
  keepOrg
}) {
  if (reuseExistingOrg && !upgradeOnly && !(releasePair && keepOrg)) {
    throw new Error(
      "--reuse-existing-org requires --upgrade-only or --release-pair --keep-org."
    );
  }
}

/** Matches a retained subscriber org to its active Dev Hub release-pair receipt. */
export function assertRetainedReleaseOrg({
  orgId,
  namespace,
  securityMode,
  version,
  records
}) {
  if (
    !/^00D[0-9A-Za-z]{12}(?:[0-9A-Za-z]{3})?$/.test(orgId ?? "") ||
    namespace
  ) {
    throw new Error(
      "Release-pair reuse requires an identified subscriber org without a namespace."
    );
  }
  const description = `Record Health Check ${version} ${securityMode} release pair`;
  const matches = records.filter(
    (record) =>
      String(record.ScratchOrg ?? "").slice(0, 15) === orgId.slice(0, 15) &&
      record.Description === description &&
      record.Status === "Active"
  );
  if (matches.length !== 1) {
    throw new Error(
      "Existing org must match one active release-pair receipt on the selected Dev Hub."
    );
  }
}

export function securityRetrieveDirectory(projectRoot) {
  return fs.mkdtempSync(path.join(projectRoot, "rhc-retained-security-"));
}
