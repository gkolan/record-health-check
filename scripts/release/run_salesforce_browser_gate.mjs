#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  browserEvidencePaths,
  assertBrowserReport,
  redactBrowserEvidence,
  browserEvidenceHtml
} from "../lib/browser-evidence.mjs";

process.env.SF_DISABLE_LOG_FILE ??= "true";

function option(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : null;
}

function execute(command, args, { capture = false, env = process.env } = {}) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    env,
    stdio: capture ? "pipe" : "inherit"
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    if (capture && result.stdout) process.stderr.write(result.stdout);
    if (capture && result.stderr) process.stderr.write(result.stderr);
    throw new Error(`${command} exited with status ${result.status}.`);
  }
  return result.stdout;
}

function executeJson(command, args) {
  return JSON.parse(execute(command, [...args, "--json"], { capture: true }));
}

const targetOrg = option("--target-org");
const securityMode = option("--security-mode");
const existingRestrictedOrg = option("--restricted-org");
const installedPackage = option("--installed-package");

if (!targetOrg || !["LWS", "Locker"].includes(securityMode)) {
  process.stderr.write(
    "Usage: run_salesforce_browser_gate.mjs --target-org <alias> --security-mode <LWS|Locker>\n"
  );
  process.exit(2);
}

const accountIds = [];
const fixtureToken = `${Date.now()}-${process.pid}`;
const restrictedAlias =
  existingRestrictedOrg ?? `rhc-restricted-${process.pid}`;
let restrictedUserId;
let restrictedCurrentPassword;
let restrictedNewPassword;
try {
  const builderPage = executeJson("sf", [
    "data",
    "query",
    "--target-org",
    targetOrg,
    "--use-tooling-api",
    "--query",
    "SELECT Id FROM FlexiPage WHERE DeveloperName = 'RHCReleaseMatrixBuilderPage' LIMIT 1"
  ]).result?.records?.[0];
  if (!builderPage?.Id) {
    throw new Error("The App Builder release-gate FlexiPage is not deployed.");
  }
  if (!existingRestrictedOrg) {
    executeJson("sf", [
      "org",
      "create",
      "user",
      "--target-org",
      targetOrg,
      "--set-alias",
      restrictedAlias
    ]);
  }
  // `sf org create user` has returned strings, objects, and arrays across CLI
  // releases. Resolve the canonical username from the alias it just created.
  const restrictedUser = executeJson("sf", [
    "org",
    "display",
    "--target-org",
    restrictedAlias
  ]).result;
  const restrictedUsername =
    typeof restrictedUser === "string"
      ? restrictedUser
      : restrictedUser?.username;
  if (!restrictedUsername) {
    throw new Error("Salesforce did not return the restricted username.");
  }
  restrictedUserId = executeJson("sf", [
    "data",
    "query",
    "--target-org",
    targetOrg,
    "--query",
    `SELECT Id FROM User WHERE Username = '${restrictedUsername}' LIMIT 1`
  ]).result?.records?.[0]?.Id;
  if (!restrictedUserId) {
    throw new Error("The restricted scratch-org user could not be resolved.");
  }
  if (existingRestrictedOrg) {
    execute("sf", [
      "data",
      "update",
      "record",
      "--target-org",
      targetOrg,
      "--sobject",
      "User",
      "--record-id",
      restrictedUserId,
      "--values",
      "IsActive=true"
    ]);
  }
  // Provisioning a scratch user without a generated password leaves its
  // frontdoor session at Salesforce's mandatory first-login password screen.
  // Generate the test-only credential (captured, never printed) so the browser
  // gate reaches the record page and actually exercises the restricted persona.
  const passwordResult = executeJson("sf", [
    "org",
    "generate",
    "password",
    "--target-org",
    restrictedAlias
  ]);
  const generatedPassword = passwordResult.result?.password;
  if (!generatedPassword) {
    throw new Error("Salesforce did not return the generated test password.");
  }
  restrictedCurrentPassword = generatedPassword;
  restrictedNewPassword = `${generatedPassword}Rhc9`;
  const cardPermission = executeJson("sf", [
    "data",
    "query",
    "--target-org",
    targetOrg,
    "--query",
    "SELECT Name, NamespacePrefix FROM PermissionSet WHERE Name = 'Record_Health_Check_Card_User' AND IsOwnedByProfile = false"
  ]).result?.records;
  if (cardPermission?.length !== 1)
    throw new Error("Expected one package Card User permission set.");
  const cardPermissionName = `${cardPermission[0].NamespacePrefix ? `${cardPermission[0].NamespacePrefix}__` : ""}${cardPermission[0].Name}`;
  const existingAssignment = executeJson("sf", [
    "data",
    "query",
    "--target-org",
    targetOrg,
    "--query",
    `SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = '${restrictedUserId}' AND PermissionSet.Name = 'Record_Health_Check_Card_User' LIMIT 1`
  ]).result?.records?.[0];
  if (!existingAssignment?.Id) {
    execute("sf", [
      "org",
      "assign",
      "permset",
      "--target-org",
      targetOrg,
      "--on-behalf-of",
      restrictedUsername,
      "--name",
      cardPermissionName
    ]);
  }
  const created = executeJson("sf", [
    "data",
    "create",
    "record",
    "--target-org",
    targetOrg,
    "--sobject",
    "Account",
    "--values",
    `Name='Aster ${securityMode} ${fixtureToken}' Phone='3125550100' Industry='Technology' BillingCity='Chicago'`
  ]);
  const accountId = created.result?.id;
  if (!accountId)
    throw new Error("Salesforce did not return the fixture Account ID.");
  accountIds.push(accountId);
  const secondAccountName = `Zephyr ${securityMode} ${fixtureToken}`;
  const secondCreated = executeJson("sf", [
    "data",
    "create",
    "record",
    "--target-org",
    targetOrg,
    "--sobject",
    "Account",
    "--values",
    `Name='${secondAccountName}' Phone='3125550101' Industry='Technology' BillingCity='Chicago'`
  ]);
  const secondAccountId = secondCreated.result?.id;
  if (!secondAccountId)
    throw new Error("Salesforce did not return the second fixture Account ID.");
  accountIds.push(secondAccountId);
  const restrictedCreated = executeJson("sf", [
    "data",
    "create",
    "record",
    "--target-org",
    restrictedAlias,
    "--sobject",
    "Account",
    "--values",
    `Name='Quartz ${securityMode} ${fixtureToken}' Phone='3125550102' Industry='Technology' BillingCity='Chicago'`
  ]);
  const restrictedAccountId = restrictedCreated.result?.id;
  if (!restrictedAccountId) {
    throw new Error("Salesforce did not return the restricted Account ID.");
  }
  accountIds.push(restrictedAccountId);

  function frontdoorUrl(orgAlias, path) {
    const opened = executeJson("sf", [
      "org",
      "open",
      "--target-org",
      orgAlias,
      "--path",
      path,
      "--url-only"
    ]);
    const url = opened.result?.url;
    if (!url) throw new Error("Salesforce did not return a frontdoor URL.");
    return url;
  }

  function runBrowserSpec(browser, spec, env) {
    const evidence = browserEvidencePaths(
      `${securityMode.toLowerCase()}-${fixtureToken}`,
      browser,
      spec
    );
    // Keep unsanitized reporter output outside all artifact-upload directories.
    const temporary = fs.mkdtempSync(
      path.join(os.tmpdir(), "rhc-browser-report-")
    );
    const rawReport = path.join(temporary, "result.json");
    const environment = {
      ...process.env,
      ...env,
      RHC_BROWSER_OUTPUT: evidence.output,
      RHC_BROWSER_JSON: rawReport
    };
    try {
      const result = spawnSync(
        "npm",
        ["run", "test:browser", "--", `--project=${browser}`, spec],
        {
          encoding: "utf8",
          env: environment,
          stdio: "pipe",
          maxBuffer: 64 * 1024 * 1024,
          timeout: 10 * 60 * 1000
        }
      );
      for (const output of [result.stdout, result.stderr]) {
        if (output)
          process.stdout.write(redactBrowserEvidence(output, environment));
      }
      if (!fs.existsSync(rawReport))
        throw new Error("Browser execution did not produce a result report.");
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
      if (result.error)
        throw new Error(
          `Browser execution failed: ${result.error.code || "process error"}`
        );
      if (result.status !== 0)
        throw new Error(
          `Browser execution exited with status ${result.status}.`
        );
      assertBrowserReport(JSON.parse(sanitized));
    } finally {
      fs.rmSync(temporary, { recursive: true, force: true });
    }
  }

  const restrictedSetupUrl = frontdoorUrl(
    restrictedAlias,
    "/lightning/page/home"
  );
  runBrowserSpec("chromium", "tests/browser/restricted-user-setup.spec.mjs", {
    RHC_RESTRICTED_SETUP_URL: restrictedSetupUrl,
    RHC_RESTRICTED_CURRENT_PASSWORD: restrictedCurrentPassword,
    RHC_RESTRICTED_NEW_PASSWORD: restrictedNewPassword
  });

  for (const browser of ["chromium", "firefox"]) {
    const url = frontdoorUrl(
      targetOrg,
      `/lightning/r/Account/${accountId}/view`
    );
    runBrowserSpec(browser, "tests/browser/release-matrix.spec.mjs", {
      RHC_BROWSER_URL: url,
      RHC_EXPECTED_AUTOMATIC_PASSED: installedPackage ? "4" : "3",
      RHC_SECURITY_MODE: securityMode,
      RHC_SECOND_ACCOUNT_ID: secondAccountId,
      RHC_SECOND_ACCOUNT_NAME: secondAccountName
    });

    const builderUrl = frontdoorUrl(
      targetOrg,
      "/lightning/setup/FlexiPageList/home"
    );
    runBrowserSpec(browser, "tests/browser/app-builder.spec.mjs", {
      RHC_BROWSER_URL: builderUrl,
      RHC_BUILDER_URL: builderUrl,
      RHC_BUILDER_PAGE_LABEL: "RHC Release Matrix Builder Page",
      RHC_SECURITY_MODE: securityMode
    });

    const restrictedUrl = frontdoorUrl(
      restrictedAlias,
      `/lightning/r/Account/${restrictedAccountId}/view`
    );
    runBrowserSpec(browser, "tests/browser/restricted-persona.spec.mjs", {
      RHC_BROWSER_URL: restrictedUrl,
      RHC_EXPECTED_AUTOMATIC_PASSED: installedPackage ? "4" : "3",
      RHC_RESTRICTED_BROWSER_URL: restrictedUrl,
      RHC_SECURITY_MODE: securityMode
    });
  }
} finally {
  for (const accountId of accountIds) {
    const cleanup = spawnSync(
      "sf",
      [
        "data",
        "delete",
        "record",
        "--target-org",
        targetOrg,
        "--sobject",
        "Account",
        "--record-id",
        accountId
      ],
      { stdio: "inherit" }
    );
    if (cleanup.status !== 0) {
      process.stderr.write(
        `Warning: browser fixture Account ${accountId} could not be deleted.\n`
      );
    }
  }
  if (restrictedUserId) {
    const deactivate = spawnSync(
      "sf",
      [
        "data",
        "update",
        "record",
        "--target-org",
        targetOrg,
        "--sobject",
        "User",
        "--record-id",
        restrictedUserId,
        "--values",
        "IsActive=false"
      ],
      { stdio: "inherit" }
    );
    if (deactivate.status !== 0) {
      process.stderr.write(
        `Warning: restricted browser user ${restrictedUserId} could not be deactivated.\n`
      );
    }
  }
}
