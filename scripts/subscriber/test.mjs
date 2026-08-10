#!/usr/bin/env node

import { parseArgs } from "node:util";
import { paths } from "../lib/paths.mjs";
import { stablePackageVersionId } from "../lib/package-releases.mjs";
import { run } from "../lib/run.mjs";

const { values } = parseArgs({
  options: {
    alias: { type: "string", default: process.env.RHC_ORG_ALIAS ?? "rhc-demo" }
  }
});

run("sf", [
  "apex",
  "run",
  "test",
  "--class-names",
  "RHCSubscriberSmokeTest",
  "--target-org",
  values.alias,
  "--result-format",
  "human",
  "--wait",
  "30"
]);

console.log(
  `Subscriber smoke tests passed in ${values.alias}. Package source at ${paths.packageRoot} was not deployed.`
);
