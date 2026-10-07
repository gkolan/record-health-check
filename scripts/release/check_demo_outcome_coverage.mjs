#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import {
  demoOutcomeCoverageGaps,
  exampleCategoryGaps
} from "../lib/demo-outcome-coverage.mjs";
import { paths } from "../lib/paths.mjs";

const matrix = JSON.parse(
  fs.readFileSync(
    path.join(paths.subscriberData, "readiness-scenarios.json"),
    "utf8"
  )
);
const gaps = [
  ...demoOutcomeCoverageGaps(
    path.join(paths.forceApp, "main/default/customMetadata"),
    matrix
  ),
  ...exampleCategoryGaps(
    path.join(paths.integrationTests, "main/default/customMetadata")
  )
];
if (gaps.length) {
  console.error("Demo outcome coverage failed:\n- " + gaps.join("\n- "));
  process.exit(1);
}
console.log(
  "Every packaged example Check Set has healthy and needs-review records; every active Check has executable PASS and FAIL scenarios, plus applicable skipped and unable outcomes."
);
