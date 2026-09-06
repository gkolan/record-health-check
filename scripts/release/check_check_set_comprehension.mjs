#!/usr/bin/env node

/**
 * Fails when a Check Set card cannot be understood at a glance, or when a Check
 * on it leaves a reader-facing field empty. The rules, the card kinds, and the
 * field tiers are defined in ../lib/check-set-comprehension.mjs.
 */

import fs from "node:fs";
import path from "node:path";
import { paths } from "../lib/paths.mjs";
import { comprehensionFindings } from "../lib/check-set-comprehension.mjs";

const directories = [
  path.join(paths.integrationTests, "main/default/customMetadata"),
  path.join(
    paths.integrationTests,
    "foreign-namespace/main/default/customMetadata"
  )
];

const decode = (value) =>
  value
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&quot;", '"')
    .replaceAll("&apos;", "'")
    .replaceAll("&amp;", "&");

/** field -> value for one Custom Metadata record; blank and nil are absent. */
const valuesOf = (xml) => {
  const values = new Map();
  for (const block of xml.matchAll(/<values>([\s\S]*?)<\/values>/g)) {
    const field = block[1].match(/<field>([^<]+)<\/field>/)?.[1]?.trim();
    const raw = block[1].match(/<value[^>]*>([\s\S]*?)<\/value>/)?.[1];
    const text = decode((raw ?? "").replace(/\s+/g, " ").trim());
    if (field && text) values.set(field, text);
  }
  return values;
};

const sets = [];
const checks = [];
for (const directory of directories) {
  if (!fs.existsSync(directory)) continue;
  for (const fileName of fs.readdirSync(directory).sort()) {
    if (!fileName.endsWith(".md-meta.xml")) continue;
    const api = fileName.split(".")[1];
    const xml = fs.readFileSync(path.join(directory, fileName), "utf8");
    const values = valuesOf(xml);
    if (fileName.startsWith("Record_Health_Check_Set.")) {
      sets.push({
        api,
        label: decode(
          (xml.match(/<label>([\s\S]*?)<\/label>/)?.[1] ?? "")
            .replace(/\s+/g, " ")
            .trim()
        ),
        title: values.get("CardTitle__c") ?? "",
        subtitle: values.get("CardSubtitle__c") ?? ""
      });
    } else {
      checks.push({
        api,
        set: values.get("Record_Health_Check_Set__c") ?? "(none)",
        fields: new Set(values.keys())
      });
    }
  }
}

const findings = comprehensionFindings(sets, checks);
if (findings.length > 0) {
  console.error(
    "Check Set fixtures do not read clearly:\n" +
      findings.map((finding) => `  ${finding}`).join("\n")
  );
  process.exit(1);
}

console.log(
  `Verified card comprehension: ${sets.length} Check Sets with distinct titles ` +
    `and readable subtitles, and ${checks.length} Checks with their reader-facing fields.`
);
