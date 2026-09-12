#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { parseArgs } from "node:util";
import {
  assertBrowserReport,
  browserEvidenceHtml,
  browserEvidencePaths,
  redactBrowserEvidence
} from "../lib/browser-evidence.mjs";

const { values } = parseArgs({
  options: {
    "target-org": { type: "string" },
    "security-mode": { type: "string" }
  }
});
const targetOrg = values["target-org"];
const securityMode = values["security-mode"];
if (!targetOrg || !["LWS", "Locker"].includes(securityMode)) {
  console.error(
    "Pass --target-org <existing alias> and --security-mode <LWS|Locker>."
  );
  process.exit(1);
}

const executeJson = (command, args) => {
  const execution = spawnSync(command, [...args, "--json"], {
    encoding: "utf8",
    env: { ...process.env, SF_DISABLE_LOG_FILE: "true" },
    maxBuffer: 32 * 1024 * 1024
  });
  if (execution.status !== 0) {
    process.stderr.write(execution.stderr ?? "");
    process.stderr.write(execution.stdout ?? "");
    process.exit(execution.status ?? 1);
  }
  const jsonStart = execution.stdout.indexOf("{");
  return JSON.parse(execution.stdout.slice(jsonStart));
};

const records = executeJson("sf", [
  "data",
  "query",
  "--target-org",
  targetOrg,
  "--query",
  "SELECT Id, Name FROM Account WHERE Name IN ('RHC Link Needs Review', 'RHC Link Missing Destination', 'RHC Link Unsafe Destination', 'RHC Link Healthy Unsafe Destination')"
]).result.records;
const idsByName = new Map(records.map((record) => [record.Name, record.Id]));
for (const name of [
  "RHC Link Needs Review",
  "RHC Link Missing Destination",
  "RHC Link Unsafe Destination",
  "RHC Link Healthy Unsafe Destination"
]) {
  if (!idsByName.has(name))
    throw new Error(`Missing URL-story browser fixture: ${name}`);
}

const runToken = `${securityMode.toLowerCase()}-${Date.now()}-${process.pid}`;
for (const browser of ["chromium", "firefox"]) {
  const openResult = executeJson("sf", [
    "org",
    "open",
    "--target-org",
    targetOrg,
    "--path",
    `/lightning/r/Account/${idsByName.get("RHC Link Needs Review")}/view`,
    "--url-only"
  ]);
  const frontdoorUrl = openResult.result?.url;
  if (!frontdoorUrl)
    throw new Error("Salesforce did not return a frontdoor URL.");

  const evidence = browserEvidencePaths(runToken, browser, "url-story");
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "rhc-url-browser-"));
  const rawReport = path.join(temporary, "result.json");
  const environment = {
    ...process.env,
    RHC_BROWSER_URL: frontdoorUrl,
    RHC_SECURITY_MODE: securityMode,
    RHC_MISSING_DESTINATION_ID: idsByName.get("RHC Link Missing Destination"),
    RHC_UNSAFE_DESTINATION_ID: idsByName.get("RHC Link Unsafe Destination"),
    RHC_HEALTHY_UNSAFE_DESTINATION_ID: idsByName.get(
      "RHC Link Healthy Unsafe Destination"
    ),
    RHC_BROWSER_OUTPUT: evidence.output,
    RHC_BROWSER_JSON: rawReport
  };
  try {
    const execution = spawnSync(
      "npm",
      [
        "run",
        "test:browser",
        "--",
        `--project=${browser}`,
        "tests/browser/url-story.spec.mjs"
      ],
      {
        encoding: "utf8",
        env: environment,
        maxBuffer: 64 * 1024 * 1024,
        timeout: 10 * 60 * 1000
      }
    );
    for (const output of [execution.stdout, execution.stderr]) {
      if (output)
        process.stdout.write(redactBrowserEvidence(output, environment));
    }
    if (!fs.existsSync(rawReport))
      throw new Error("Browser reporter produced no JSON.");
    const sanitized = redactBrowserEvidence(
      fs.readFileSync(rawReport, "utf8"),
      environment
    );
    fs.mkdirSync(evidence.output, { recursive: true });
    fs.mkdirSync(evidence.html, { recursive: true });
    fs.writeFileSync(evidence.json, sanitized);
    fs.writeFileSync(
      path.join(evidence.html, "index.html"),
      browserEvidenceHtml(sanitized)
    );
    if (execution.error) throw execution.error;
    if (execution.status !== 0) {
      throw new Error(
        `${browser} URL-story browser run exited ${execution.status}.`
      );
    }
    assertBrowserReport(JSON.parse(sanitized));
    console.log(`${browser} URL-story browser evidence: ${evidence.json}`);
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}
