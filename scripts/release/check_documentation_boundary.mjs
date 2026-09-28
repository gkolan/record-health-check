#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const failures = [];
const documentationExtensions = new Set([
  ".md",
  ".mdx",
  ".xml",
  ".yaml",
  ".yml"
]);
const ignoredDirectoryNames = new Set([
  ".git",
  ".astro",
  "dist",
  "node_modules",
  "reports"
]);
const historicalProductVersion =
  /\b2\.0\.(?:0|1|2|3|4|5|6|7|8|9|10)(?:[.-]\d+)?\b/i;
const documentationGeneration = /\bV[123]\b/i;

for (const directory of ["v1", "v2", "v3"]) {
  if (fs.existsSync(path.join(root, directory))) {
    failures.push(
      `${directory}/: version-branded documentation must stay outside the active repository.`
    );
  }
}

if (!fs.existsSync(path.join(root, "docs", "README.md"))) {
  failures.push("docs/: canonical documentation is missing.");
}
if (fs.existsSync(path.join(root, "docs", "VERSION.md"))) {
  failures.push(
    "docs/VERSION.md: a day-one documentation set must not expose a version index."
  );
}

const packageJson = JSON.parse(
  fs.readFileSync(path.join(root, "package.json"), "utf8")
);
for (const scriptName of ["prettier", "prettier:verify"]) {
  const command = packageJson.scripts?.[scriptName] ?? "";
  if (!command.includes('"docs/**/*.md"')) {
    failures.push(
      `package.json: ${scriptName} must include canonical documentation.`
    );
  }
  for (const archivedPattern of [
    '"v1/**/*.md"',
    '"v2/**/*.md"',
    '"v3/**/*.md"'
  ]) {
    if (command.includes(archivedPattern)) {
      failures.push(
        `package.json: ${scriptName} must not include version-branded pattern ${archivedPattern}.`
      );
    }
  }
}

function isIgnored(relative) {
  const segments = relative.split("/");
  return (
    segments.some((segment) => ignoredDirectoryNames.has(segment)) ||
    relative === "internal" ||
    relative.startsWith("internal/") ||
    relative === "site/src/content/docs" ||
    relative.startsWith("site/src/content/docs/")
  );
}

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    const relative = path.relative(root, absolute).split(path.sep).join("/");
    if (isIgnored(relative)) continue;
    if (entry.isDirectory()) {
      walk(absolute);
      continue;
    }
    if (!documentationExtensions.has(path.extname(entry.name))) continue;
    const source = fs.readFileSync(absolute, "utf8");
    if (historicalProductVersion.test(source)) {
      failures.push(`${relative}: references an older product version.`);
    }
    if (documentationGeneration.test(source)) {
      failures.push(
        `${relative}: uses retired documentation-generation branding.`
      );
    }
  }
}

walk(root);

if (failures.length) {
  console.error(
    "Documentation boundary check failed:\n- " + failures.join("\n- ")
  );
  process.exit(1);
}

console.log(
  "Documentation boundary verified: docs/ is canonical, unversioned, and contains no older product references."
);
