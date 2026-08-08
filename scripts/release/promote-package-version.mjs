#!/usr/bin/env node

import { parseArgs } from "node:util";
import { readPackageReleases } from "../lib/package-releases.mjs";
import { run } from "../lib/run.mjs";

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    "dev-hub": { type: "string", default: process.env.DEV_HUB_ALIAS ?? "" },
    package: { type: "string" }
  }
});

const devHub = values["dev-hub"];
if (!devHub) {
  console.error("Set DEV_HUB_ALIAS or pass --dev-hub.");
  process.exit(1);
}

const releases = readPackageReleases();
const packageVersionId =
  values.package ??
  positionals[0] ??
  releases.stable?.subscriberPackageVersionId ??
  "";

if (!packageVersionId.startsWith("04t")) {
  console.error(
    "Pass a candidate 04t via --package or as the first positional argument."
  );
  process.exit(1);
}

run("sf", [
  "package",
  "version",
  "promote",
  "--package",
  packageVersionId,
  "--target-dev-hub",
  devHub
]);

console.log("");
console.log(`Promoted ${packageVersionId}.`);
console.log("Update config/package-releases.json:");
console.log("  1. Move the current stable 04t into previous.");
console.log("  2. Set stable.subscriberPackageVersionId to the promoted 04t.");
console.log("  3. Refresh installUrl production and sandbox p0 values.");
console.log(
  "Subscriber scripts and docs read from that file; do not duplicate 04t IDs elsewhere."
);
