import fs from "node:fs";
import { readPackageReleases } from "../lib/package-releases.mjs";
import { releaseUpgradeBases } from "../lib/release-upgrades.mjs";

const matrix = JSON.parse(
  fs.readFileSync(
    new URL("../../config/release-runtime-matrix.json", import.meta.url),
    "utf8"
  )
);
const stage = process.argv[2];
const base = releaseUpgradeBases(matrix, readPackageReleases()).find(
  (b) => stage === `upgrade-${b.version}`
);
if (!base) throw new Error("Select a reviewed upgrade stage.");
process.stdout.write(base.subscriberPackageVersionId);
