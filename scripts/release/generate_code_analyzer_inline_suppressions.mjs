#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import {
  compareInlineSuppressionInventory,
  inspectInlineSuppressions
} from "../lib/code-analyzer-inline-suppressions.mjs";

const root = process.cwd();
const inventoryPath = path.join(
  root,
  "config/code-analyzer-inline-suppressions.json"
);
const sourceRoots = [
  "packages/record-health-check/force-app",
  "packages/record-health-check/integration-tests",
  "subscriber-app"
];

function filesUnder(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const child = path.join(directory, entry.name);
    return entry.isDirectory() ? filesUnder(child) : [child];
  });
}

const files = sourceRoots
  .flatMap((sourceRoot) => filesUnder(path.join(root, sourceRoot)))
  .filter((file) => /\.(?:cls|trigger|js|xml)$/.test(file))
  .sort();
const entries = [];
const errors = [];
for (const file of files) {
  const relative = path.relative(root, file).split(path.sep).join("/");
  const inspected = inspectInlineSuppressions(
    relative,
    fs.readFileSync(file, "utf8")
  );
  entries.push(...inspected.entries);
  errors.push(...inspected.errors);
}
if (errors.length > 0) {
  throw new Error(
    `Inline suppression policy failed:\n- ${errors.join("\n- ")}`
  );
}

const inventory = { schemaVersion: 1, entries };
if (process.argv.includes("--write")) {
  fs.writeFileSync(inventoryPath, `${JSON.stringify(inventory, null, 2)}\n`);
  console.log(
    `Wrote ${entries.length} reviewed inline suppressions to ${path.relative(root, inventoryPath)}.`
  );
  process.exit(0);
}

if (!fs.existsSync(inventoryPath)) {
  throw new Error(
    `${path.relative(root, inventoryPath)} is missing; generate and review it before release.`
  );
}
const expected = JSON.parse(fs.readFileSync(inventoryPath, "utf8"));
if (expected.schemaVersion !== 1 || !Array.isArray(expected.entries)) {
  throw new Error("Inline suppression inventory has an invalid schema.");
}
const differences = compareInlineSuppressionInventory(
  entries,
  expected.entries
);
if (differences.length > 0) {
  throw new Error(
    `Inline suppression policy failed:\n- ${differences.join("\n- ")}`
  );
}
console.log(
  `Inline suppression policy passed: exactly ${entries.length} reviewed source markers.`
);
