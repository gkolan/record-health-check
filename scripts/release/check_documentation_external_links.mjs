#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const docsRoot = path.join(root, "docs");
const live = process.argv.includes("--live");
const markdownFiles = [];
const occurrences = new Map();
const failures = [];
const reviewedLiveExceptions = [];
const allowedHosts = new Set([
  "developer.salesforce.com",
  "github.com",
  "help.salesforce.com",
  "login.salesforce.com",
  "recordhealthcheck.com",
  "test.salesforce.com",
  "trailhead.salesforce.com"
]);
const reviewedLiveStatusExceptions = new Map([
  [
    "https://developer.salesforce.com/docs/ai/agentforce/guide/apex-examples-custom-action.html",
    new Set([503])
  ]
]);

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(entryPath);
    else if (entry.name.endsWith(".md")) markdownFiles.push(entryPath);
  }
}

function lineNumber(source, index) {
  return source.slice(0, index).split("\n").length;
}

walk(docsRoot);
for (const file of markdownFiles) {
  const source = fs.readFileSync(file, "utf8");
  const relative = path.relative(root, file).split(path.sep).join("/");
  for (const match of source.matchAll(
    /!?\[[^\]]*\]\((https?:\/\/[^\s)]+)(?:\s+["'][^"']*["'])?\)/g
  )) {
    const href = match[1];
    let url;
    try {
      url = new URL(href);
    } catch {
      failures.push(
        `${relative}:${lineNumber(source, match.index)}: invalid URL ${href}`
      );
      continue;
    }
    if (url.protocol !== "https:") {
      failures.push(
        `${relative}:${lineNumber(source, match.index)}: external documentation links must use HTTPS: ${href}`
      );
    }
    if (!allowedHosts.has(url.hostname)) {
      failures.push(
        `${relative}:${lineNumber(source, match.index)}: unreviewed external host ${url.hostname}`
      );
    }
    const locations = occurrences.get(url.href) ?? [];
    locations.push(`${relative}:${lineNumber(source, match.index)}`);
    occurrences.set(url.href, locations);
  }
}

if (occurrences.size === 0) {
  failures.push("Canonical documentation has no external links to verify.");
}

async function fetchWithTimeout(url) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20_000);
  try {
    return await fetch(url, {
      headers: { "user-agent": "Record-Health-Check-Docs-link-verifier/1.0" },
      redirect: "follow",
      signal: controller.signal
    });
  } finally {
    clearTimeout(timeout);
  }
}

async function checkLive(url) {
  let response;
  let lastError;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      response = await fetchWithTimeout(url);
      if (response.status < 500 || attempt === 3) break;
    } catch (error) {
      lastError = error;
      if (attempt === 3) break;
    }
    await new Promise((resolve) => setTimeout(resolve, 750 * attempt));
  }

  if (!response) {
    failures.push(
      `${occurrences.get(url)[0]}: external link could not be reached: ${url} (${lastError?.message ?? "unknown error"})`
    );
    return;
  }

  if (
    response.status === 404 ||
    response.status === 410 ||
    response.status >= 500
  ) {
    const allowedStatuses = reviewedLiveStatusExceptions.get(url);
    if (allowedStatuses?.has(response.status)) {
      reviewedLiveExceptions.push(`${response.status} ${url}`);
      return;
    }
    failures.push(
      `${occurrences.get(url)[0]}: external link returned ${response.status}: ${url}`
    );
  }
}

if (live && failures.length === 0) {
  const urls = [...occurrences.keys()];
  const workers = Array.from({ length: Math.min(4, urls.length) }, async () => {
    while (urls.length) await checkLive(urls.shift());
  });
  await Promise.all(workers);
}

if (failures.length) {
  console.error(
    `Documentation external-link verification failed:\n- ${failures.join("\n- ")}`
  );
  process.exit(1);
}

console.log(
  `${live ? "Live" : "Structural"} documentation external-link verification passed for ${occurrences.size} unique HTTPS links across ${markdownFiles.length} pages.`
);
if (reviewedLiveExceptions.length) {
  console.log(
    `Accepted ${reviewedLiveExceptions.length} exact reviewed CDN response: ${reviewedLiveExceptions.join(", ")}`
  );
}
