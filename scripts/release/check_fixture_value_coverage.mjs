#!/usr/bin/env node

/**
 * Fails when a Check or Check Set configuration value an administrator can
 * choose has no integration-test fixture. Without this gate a new picklist
 * value ships with no sandbox verification path, which the regression-first
 * contract in AGENTS.md and CLAUDE.md does not allow.
 */

import fs from "node:fs";
import path from "node:path";
import { paths } from "../lib/paths.mjs";
import {
  coverageGaps,
  decodeXmlText,
  displayFormats,
  fieldLength,
  fixtureValues,
  lengthGaps,
  picklistValues,
  surfaceGaps,
  tokenProperties
} from "../lib/fixture-value-coverage.mjs";

const objects = ["Record_Health_Check__mdt", "Record_Health_Check_Set__mdt"];

const declared = new Map();
const limits = new Map();
for (const object of objects) {
  const directory = path.join(
    paths.forceApp,
    "main/default/objects",
    object,
    "fields"
  );
  for (const fileName of fs.readdirSync(directory).sort()) {
    if (!fileName.endsWith(".field-meta.xml")) continue;
    const fieldXml = fs.readFileSync(path.join(directory, fileName), "utf8");
    const field = fileName.replace(".field-meta.xml", "");
    const limit = fieldLength(fieldXml);
    if (limit !== null) limits.set(`${object}.${field}`, limit);
    const values = picklistValues(fieldXml);
    if (values.length > 0) {
      declared.set(`${object}.${field}`, values);
    }
  }
}

const used = new Map();
const fixtureRoots = [
  path.join(paths.integrationTests, "main/default/customMetadata"),
  path.join(
    paths.integrationTests,
    "foreign-namespace/main/default/customMetadata"
  )
];
let fixtureCount = 0;
const fixtureText = [];
const records = [];
for (const directory of fixtureRoots) {
  if (!fs.existsSync(directory)) continue;
  for (const fileName of fs.readdirSync(directory).sort()) {
    if (!fileName.endsWith(".md-meta.xml")) continue;
    fixtureCount += 1;
    const object = fileName.startsWith("Record_Health_Check_Set.")
      ? "Record_Health_Check_Set__mdt"
      : "Record_Health_Check__mdt";
    // Metadata may carry a token's quotes as &quot;, which is the same
    // configuration; decode before the surface patterns are matched.
    const text = fs.readFileSync(path.join(directory, fileName), "utf8");
    fixtureText.push(decodeXmlText(text));
    const pairs = fixtureValues(text);
    records.push({
      file: fileName.replace(".md-meta.xml", ""),
      label: decodeXmlText(
        (text.match(/<label>([\s\S]*?)<\/label>/)?.[1] ?? "")
          .replace(/\s+/g, " ")
          .trim()
      ),
      values: pairs.map(([field, value]) => [`${object}.${field}`, value])
    });
    for (const [field, value] of pairs) {
      const key = `${object}.${field}`;
      if (!used.has(key)) used.set(key, new Set());
      used.get(key).add(value);
    }
  }
}

// ── Merge-token grammar and inline display formats ──────────────────────────
// Both are read out of the classes that implement them, so a token or format
// added to the product cannot ship without a fixture that renders it.
const classes = path.join(paths.forceApp, "main/default/classes");
const resolver = fs.readFileSync(
  path.join(classes, "RecordHealthCheckTemplateValueResolver.cls"),
  "utf8"
);
const required = new Map([
  ...[
    ["rhcCheck", "checkValue"],
    ["rhcSet", "setValue"],
    ["rhcResult", "resultValue"],
    ["rhcRun", "runValue"]
  ].map(([namespace, method]) => [
    `Merge token ${namespace}`,
    tokenProperties(resolver, method)
  ]),
  [
    'Inline format="…" modifier',
    displayFormats(
      fs.readFileSync(
        path.join(classes, "RecordHealthCheckDisplayFormat.cls"),
        "utf8"
      )
    )
  ]
]);

const seen = new Map();
const note = (surface, item) => {
  if (!seen.has(surface)) seen.set(surface, new Set());
  seen.get(surface).add(item);
};
for (const text of fixtureText) {
  for (const [, namespace, property] of text.matchAll(
    /\{!\s*(rhcCheck|rhcSet|rhcResult|rhcRun)\.([A-Za-z0-9_]+)/g
  )) {
    note(`Merge token ${namespace}`, property);
  }
  for (const [, format] of text.matchAll(/format="([A-Z_]+)"/g)) {
    note('Inline format="…" modifier', format);
  }
}

// A Check Set whose Checks are all inactive is its own card state — "no active
// checks (N inactive)" — and only a fixture shaped that way can show it.
const activeChecksBySet = new Map();
for (const text of fixtureText) {
  const values = new Map(fixtureValues(text));
  const parent = values.get("Record_Health_Check_Set__c");
  if (parent === undefined) continue;
  activeChecksBySet.set(
    parent,
    (activeChecksBySet.get(parent) ?? 0) +
      (values.get("IsActive__c") === "true" ? 1 : 0)
  );
}
const emptySets = [...activeChecksBySet].filter(([, count]) => count === 0);

const gaps = [
  ...coverageGaps(declared, used),
  ...surfaceGaps(required, seen),
  ...lengthGaps(limits, records)
];
if (emptySets.length === 0) {
  gaps.push(
    "Runtime state NO_ACTIVE_CHECKS has no integration-test fixture: no Check " +
      "Set fixture has Checks with every one of them inactive"
  );
}
if (gaps.length > 0) {
  console.error(
    "Integration-test fixtures do not cover every configuration value:\n" +
      gaps.map((gap) => `  ${gap}`).join("\n")
  );
  process.exit(1);
}

console.log(
  `Verified configuration coverage: ${declared.size} picklists, ` +
    `${[...required.values()].flat().length} merge-token and display-format ` +
    `surfaces, and ${limits.size} field length limits, across ${fixtureCount} ` +
    `integration-test fixtures.`
);
