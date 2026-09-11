#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";
import { assertUrlStoryEvidence } from "../lib/url-story-verifier.mjs";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const matrixPath = path.join(
  root,
  "packages/record-health-check/integration-tests/url-story-expected-results.json"
);
const { values } = parseArgs({
  options: {
    "target-org": { type: "string" },
    output: { type: "string" }
  }
});

if (!values["target-org"]) {
  console.error(
    "Pass --target-org with an existing authorized org alias or username."
  );
  process.exit(1);
}

const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
const apexString = (value) =>
  `'${value.replaceAll("\\", "\\\\").replaceAll("'", "\\'")}'`;
const recordNames = matrix.records
  .map((record) => apexString(record.name))
  .join(", ");
const checkNames = matrix.checks.map(apexString).join(", ");
const displayRows = matrix.displayCases
  .map(
    (displayCase) =>
      `new Map<String, String>{'recordName' => ${apexString(displayCase.record)}, 'checkName' => ${apexString(displayCase.check)}}`
  )
  .join(",\n  ");

const apex = `
List<String> expectedRecordNames = new List<String>{${recordNames}};
List<String> expectedCheckNames = new List<String>{${checkNames}};
Map<String, Account> accountsByName = new Map<String, Account>();
for (Account account : [
  SELECT Id, Name, NumberOfEmployees
  FROM Account
  WHERE Name IN :expectedRecordNames
]) {
  accountsByName.put(account.Name, account);
}
Map<String, Record_Health_Check__mdt> checksByName = new Map<String, Record_Health_Check__mdt>();
for (Record_Health_Check__mdt check : [
  SELECT DeveloperName, QualifiedApiName
  FROM Record_Health_Check__mdt
  WHERE DeveloperName IN :expectedCheckNames
]) {
  checksByName.put(check.DeveloperName, check);
}
Record_Health_Check_Set__mdt checkSet = [
  SELECT DeveloperName, QualifiedApiName
  FROM Record_Health_Check_Set__mdt
  WHERE DeveloperName = ${apexString(matrix.checkSet)}
  LIMIT 1
];
List<Id> recordIds = new List<Id>();
for (String recordName : expectedRecordNames) {
  recordIds.add(accountsByName.get(recordName).Id);
}
RecordHealthCheckResponse baselineResponse = RecordHealthCheckSandboxRunner.runCheckSet(
  checkSet.QualifiedApiName,
  recordIds,
  'url-story-baseline'
);
Map<Id, String> namesById = new Map<Id, String>();
for (String recordName : accountsByName.keySet()) {
  namesById.put(accountsByName.get(recordName).Id, recordName);
}
List<Object> baseline = new List<Object>();
for (RecordHealthCheckResultItem item : baselineResponse.results) {
  String qualifiedName = item.evaluation.checkQualifiedApiName;
  String developerName = qualifiedName.contains('__')
    ? qualifiedName.substringAfter('__')
    : qualifiedName;
  baseline.add(new Map<String, Object>{
    'recordName' => namesById.get(item.evaluation.recordId),
    'checkDeveloperName' => developerName,
    'status' => item.evaluation.status,
    'reasonCode' => item.evaluation.reasonCode
  });
}
List<Map<String, String>> requestedDisplays = new List<Map<String, String>>{
  ${displayRows}
};
List<Object> displays = new List<Object>();
for (Map<String, String> requested : requestedDisplays) {
  Account displayAccount = accountsByName.get(requested.get('recordName'));
  Record_Health_Check__mdt displayCheck = checksByName.get(requested.get('checkName'));
  RecordHealthCheckResultItem item = RecordHealthCheckController.evaluateCheck(
    checkSet.QualifiedApiName,
    displayCheck.QualifiedApiName,
    displayAccount.Id,
    'url-story-display',
    'RUN_ON_LOAD'
  );
  displays.add(new Map<String, Object>{
    'evaluation' => new Map<String, Object>{
      'recordName' => requested.get('recordName'),
      'checkDeveloperName' => requested.get('checkName'),
      'status' => item.evaluation.status,
      'reasonCode' => item.evaluation.reasonCode
    },
    'display' => item.display
  });
}
Account transitionAccount = accountsByName.get(${apexString(matrix.transition.record)});
Integer originalEmployeeCount = transitionAccount.NumberOfEmployees;
List<Object> transition = new List<Object>();
RecordHealthCheckResponse beforeResponse = RecordHealthCheckSandboxRunner.runCheckSet(
  checkSet.QualifiedApiName,
  new List<Id>{transitionAccount.Id},
  'url-story-transition-before'
);
List<String> beforeStatuses = new List<String>();
for (RecordHealthCheckResultItem item : beforeResponse.results) {
  beforeStatuses.add(item.evaluation.status);
}
transition.add(new Map<String, Object>{'phase' => 'before', 'statuses' => beforeStatuses});
try {
  transitionAccount.NumberOfEmployees = 1;
  Database.update(transitionAccount, AccessLevel.USER_MODE);
  RecordHealthCheckResponse changedResponse = RecordHealthCheckSandboxRunner.runCheckSet(
    checkSet.QualifiedApiName,
    new List<Id>{transitionAccount.Id},
    'url-story-transition-changed'
  );
  List<String> changedStatuses = new List<String>();
  for (RecordHealthCheckResultItem item : changedResponse.results) {
    changedStatuses.add(item.evaluation.status);
  }
  transition.add(new Map<String, Object>{'phase' => 'changed', 'statuses' => changedStatuses});
} finally {
  transitionAccount.NumberOfEmployees = originalEmployeeCount;
  Database.update(transitionAccount, AccessLevel.USER_MODE);
}
RecordHealthCheckResponse restoredResponse = RecordHealthCheckSandboxRunner.runCheckSet(
  checkSet.QualifiedApiName,
  new List<Id>{transitionAccount.Id},
  'url-story-transition-restored'
);
List<String> restoredStatuses = new List<String>();
for (RecordHealthCheckResultItem item : restoredResponse.results) {
  restoredStatuses.add(item.evaluation.status);
}
transition.add(new Map<String, Object>{'phase' => 'restored', 'statuses' => restoredStatuses});
Map<String, Object> evidence = new Map<String, Object>{
  'checkSetDeveloperName' => checkSet.DeveloperName,
  'baseline' => baseline,
  'displays' => displays,
  'transition' => transition
};
System.debug(LoggingLevel.ERROR, 'RHC_URL_STORY_JSON=' + JSON.serialize(evidence));
`;

const temporaryDirectory = fs.mkdtempSync(
  path.join(os.tmpdir(), "rhc-url-story-")
);
const apexPath = path.join(temporaryDirectory, "verify-url-story.apex");
fs.writeFileSync(apexPath, apex, "utf8");

try {
  const execution = spawnSync(
    "sf",
    [
      "apex",
      "run",
      "--file",
      apexPath,
      "--target-org",
      values["target-org"],
      "--json"
    ],
    {
      cwd: root,
      encoding: "utf8",
      env: { ...process.env, SF_DISABLE_LOG_FILE: "true" },
      maxBuffer: 32 * 1024 * 1024
    }
  );
  if (execution.stderr) process.stderr.write(execution.stderr);
  if (execution.status !== 0) {
    process.stderr.write(execution.stdout ?? "");
    process.exit(execution.status ?? 1);
  }
  const sfResult = JSON.parse(execution.stdout);
  if (
    sfResult.status !== 0 ||
    !sfResult.result?.compiled ||
    !sfResult.result?.success
  ) {
    throw new Error(
      `URL-story Apex execution failed: ${JSON.stringify(sfResult.result)}`
    );
  }
  const marker = "RHC_URL_STORY_JSON=";
  const evidenceLine = sfResult.result.logs
    .split("\n")
    .findLast((line) => line.includes("|USER_DEBUG|") && line.includes(marker));
  if (!evidenceLine)
    throw new Error("URL-story execution did not emit its evidence marker.");
  const evidence = JSON.parse(
    evidenceLine.slice(evidenceLine.indexOf(marker) + marker.length)
  );
  assertUrlStoryEvidence(matrix, evidence);

  const git = spawnSync("git", ["rev-parse", "HEAD"], {
    cwd: root,
    encoding: "utf8"
  });
  const result = {
    status: "pass",
    verifiedAt: new Date().toISOString(),
    sourceCommit: git.status === 0 ? git.stdout.trim() : null,
    targetOrg: values["target-org"],
    expectedMatrix: path.relative(root, matrixPath),
    evidence
  };
  const output = values.output
    ? path.resolve(values.output)
    : path.join(
        root,
        "reports",
        "url-story",
        `${Date.now()}-verification.json`
      );
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`, "utf8");
  console.log(`URL story verified: 7 records, 3 Checks, PASS→FAIL→PASS.`);
  console.log(`Evidence: ${output}`);
} finally {
  fs.rmSync(temporaryDirectory, { recursive: true, force: true });
}
