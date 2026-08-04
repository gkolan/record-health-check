import fs from "node:fs";
import path from "node:path";

const root = path.resolve(".");
const ignoredDirectories = new Set([
  ".git",
  ".sf",
  ".sfdx",
  "node_modules",
  "reports",
  "coverage",
  "recycle-bin",
  "releases",
  "slides_build",
  "audits",
  "slides",
  "scratch-org-setup",
  "spec",
  "specs",
  "tasks",
  "internal"
]);
const ignoredPathPrefixes = [];
const ignoredFiles = new Set([
  "LICENSE",
  "NOTICE",
  "PUBLISHING.md",
  "package-lock.json"
]);
const textExtensions = new Set([
  ".apex",
  ".cls",
  ".css",
  ".html",
  ".js",
  ".json",
  ".md",
  ".mjs",
  ".py",
  ".trigger",
  ".xml",
  ".yaml",
  ".yml"
]);
const productVersionLabel = /\bv(?:1|2)(?:\.\d+)*(?:\.x)?\b/gi;
const productGenerationPhrase =
  /\b(?:version|generation)[ _-]?(?:one|two)\b|\b(?:1|2)\.x\b|\b(?:core|product|framework)\s+(?:1|2)\.\d+(?:\.\d+)?\b|\b(?:1|2)\.\d+(?:\.\d+)?\s+(?:bulk|single-record|request|response|plugin|product|framework|core|release)\b/gi;
const failures = [];

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.isDirectory() && ignoredDirectories.has(entry.name)) continue;
    const entryPath = path.join(directory, entry.name);
    const relativePath = path
      .relative(root, entryPath)
      .split(path.sep)
      .join("/");
    if (
      ignoredPathPrefixes.some(
        (prefix) =>
          relativePath === prefix.slice(0, -1) ||
          relativePath.startsWith(prefix)
      )
    ) {
      continue;
    }
    if (entry.isDirectory()) {
      if (/^v(?:1|2)(?:[._-]|$)/i.test(entry.name)) {
        failures.push(
          `${relativePath}: remove product generation label from path`
        );
      }
      walk(entryPath);
      continue;
    }
    if (
      ignoredFiles.has(entry.name) ||
      /code-analyzer-results-.*\.json$/.test(entry.name)
    ) {
      continue;
    }
    if (!textExtensions.has(path.extname(entry.name))) continue;
    let source;
    try {
      source = fs.readFileSync(entryPath, "utf8");
    } catch {
      continue;
    }
    for (const match of source.matchAll(productVersionLabel)) {
      const line = source.slice(0, match.index).split("\n").length;
      failures.push(
        `${relativePath}:${line}: remove product generation label ${match[0]}`
      );
    }
    for (const match of source.matchAll(productGenerationPhrase)) {
      const line = source.slice(0, match.index).split("\n").length;
      failures.push(
        `${relativePath}:${line}: remove product generation phrase ${match[0]}`
      );
    }
  }
}

walk(root);
if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log(
  "Verified repository language: no product generation labels are present."
);
