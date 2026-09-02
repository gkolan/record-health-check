#!/usr/bin/env node

import assert from "node:assert/strict";

import { runJson, tryRun } from "../lib/run.mjs";
import { SalesforceClient } from "../../packages/record-health-check-mcp/dist/salesforce-client.js";

function options(argv) {
  const targetIndex = argv.indexOf("--target-org");
  const orgAlias = targetIndex >= 0 ? argv[targetIndex + 1] : undefined;
  if (!orgAlias) {
    throw new Error(
      "Pass --target-org with a deployed Record Health Check org."
    );
  }
  const namespaceIndex = argv.indexOf("--namespace");
  return {
    orgAlias,
    namespace: namespaceIndex >= 0 ? argv[namespaceIndex + 1] : undefined
  };
}

function requiredString(value, label) {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`Salesforce CLI did not return ${label}.`);
  }
  return value;
}

function deleteFixture(orgAlias, recordId) {
  const result = tryRun("sf", [
    "data",
    "delete",
    "record",
    "--sobject",
    "Account",
    "--record-id",
    recordId,
    "--target-org",
    orgAlias
  ]);
  if (result.status !== 0) {
    if (result.stderr) process.stderr.write(result.stderr);
    throw new Error("The MCP contract-test Account could not be removed.");
  }
}

async function main() {
  const input = options(process.argv.slice(2));
  const orgAlias = input.orgAlias;
  const display = runJson("sf", [
    "org",
    "display",
    "--target-org",
    orgAlias
  ]).result;
  const token = runJson("sf", [
    "org",
    "auth",
    "show-access-token",
    "--target-org",
    orgAlias
  ]).result;
  const accessToken = requiredString(token?.accessToken, "an access token");
  const instanceUrl = new URL(
    requiredString(display?.instanceUrl, "an instance URL")
  );
  const namespace =
    input.namespace ??
    (typeof display?.namespacePrefix === "string"
      ? display.namespacePrefix
      : "");
  if (namespace && !/^[a-zA-Z][a-zA-Z0-9_]*$/.test(namespace)) {
    throw new Error("The Salesforce namespace is invalid.");
  }
  const identityPrefix = namespace ? `${namespace}__` : "";
  const restPrefix = namespace ? `${namespace}/` : "";

  const created = runJson("sf", [
    "data",
    "create",
    "record",
    "--sobject",
    "Account",
    "--values",
    "Name='MCP Apex Contract' Phone='312-555-0199'",
    "--target-org",
    orgAlias
  ]).result;
  const recordId = requiredString(created?.id, "the fixture Account ID");

  let contractFailure;
  try {
    const config = {
      nodeEnv: "test",
      host: "127.0.0.1",
      port: 3000,
      allowedHosts: ["127.0.0.1"],
      allowedOrigins: ["127.0.0.1"],
      authMode: "none",
      serverUrl: new URL("https://mcp.contract.test/mcp"),
      requiredScope: "rhc.run",
      salesforce: {
        loginUrl: instanceUrl,
        clientId: "org-contract",
        clientSecret: "org-contract",
        allowedHosts: [instanceUrl.hostname],
        restPath: `/services/apexrest/${restPrefix}record-health-check/contract-1/evaluations`,
        timeoutMs: 30000,
        maxResponseBytes: 65536,
        maxRetries: 0,
        maxConcurrentCalls: 1
      },
      killSwitch: false,
      buildId: "org-contract"
    };
    const fetcher = (url, init) => {
      const target = url instanceof URL ? url : new URL(String(url));
      if (target.pathname === "/services/oauth2/token") {
        return Promise.resolve(
          new Response(
            JSON.stringify({
              access_token: accessToken,
              instance_url: instanceUrl.href,
              expires_in: 900
            }),
            { status: 200, headers: { "content-type": "application/json" } }
          )
        );
      }
      return fetch(url, init);
    };
    const client = new SalesforceClient(config, { log() {} }, fetcher);

    const check = await client.evaluate({
      operation: "RUN_CHECK",
      recordId,
      qualifiedApiName: `${identityPrefix}Example_Website_URL_Valid`,
      correlationId: "org-contract-check"
    });
    assert.equal(check.success, true);
    assert.equal(check.operation, "RUN_CHECK");
    assert.equal(check.correlationId, "org-contract-check");

    const checkSet = await client.evaluate({
      operation: "RUN_CHECK_SET",
      recordId,
      qualifiedApiName: `${identityPrefix}Example_Account_Check_Builder_Guide`,
      correlationId: "org-contract-set"
    });
    assert.equal(checkSet.success, true);
    assert.equal(checkSet.operation, "RUN_CHECK_SET");
    assert.equal(checkSet.correlationId, "org-contract-set");
    assert.equal(
      checkSet.passed +
        checkSet.failed +
        checkSet.skipped +
        checkSet.unable +
        checkSet.systemError,
      25,
      "RUN_CHECK_SET must account for every Check in the four-type release set."
    );

    process.stdout.write(
      "Live MCP-to-Apex contract passed for RUN_CHECK and RUN_CHECK_SET.\n"
    );
  } catch (error) {
    contractFailure = error;
  }

  try {
    deleteFixture(orgAlias, recordId);
  } catch (error) {
    contractFailure ??= error;
  }
  if (contractFailure) throw contractFailure;
}

main().catch((error) => {
  process.stderr.write(
    `${error instanceof Error ? error.message : "The MCP-to-Apex contract failed."}\n`
  );
  process.exitCode = 1;
});
