#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const controller = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckController.cls"
  ),
  "utf8"
);
const component = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.js"
  ),
  "utf8"
);
const componentMetadata = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.js-meta.xml"
  ),
  "utf8"
);
const runner = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/lwc/recordHealthCheck/healthCheckRunner.js"
  ),
  "utf8"
);
const constants = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckConstants.cls"
  ),
  "utf8"
);
const formulaEvaluator = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckFormulaEvaluator.cls"
  ),
  "utf8"
);
const activityCheck = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/AccountHasRecentActivityCheck.cls"
  ),
  "utf8"
);
const configService = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckConfigService.cls"
  ),
  "utf8"
);
const definitionLoader = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/force-app/main/default/classes/RecordHealthCheckDefinitionLoader.cls"
  ),
  "utf8"
);
const failures = [];

const appBuilderProperties = [
  ...componentMetadata.matchAll(
    /<property\s+[\s\S]*?name="([^"]+)"[\s\S]*?\/>/g
  )
].map((match) => match[1]);
const requiredAppBuilderProperties = ["checkSetName", "whenChecksRun"];
if (
  appBuilderProperties.length !== requiredAppBuilderProperties.length ||
  requiredAppBuilderProperties.some(
    (property, index) => appBuilderProperties[index] !== property
  )
) {
  failures.push(
    `Lightning App Builder must expose checkSetName and whenChecksRun; found: ${appBuilderProperties.join(", ") || "none"}`
  );
}
if (
  !componentMetadata.includes('name="whenChecksRun"') ||
  !componentMetadata.includes('default="Manual"') ||
  !componentMetadata.includes('required="true"')
) {
  failures.push(
    "Lightning App Builder whenChecksRun must be required and default to Manual"
  );
}

for (const parameter of [
  "String checkSetQualifiedApiName",
  "String checkQualifiedApiName"
]) {
  if (!controller.includes(parameter)) {
    failures.push(
      `Apex controller is missing required parameter: ${parameter}`
    );
  }
}

for (const retiredKey of ["checkSetDeveloperName:", "checkDeveloperName:"]) {
  if (component.includes(retiredKey) || runner.includes(retiredKey)) {
    failures.push(`Lightning Apex payload uses prohibited key: ${retiredKey}`);
  }
}

for (const requiredKey of [
  "checkSetQualifiedApiName:",
  "checkQualifiedApiName:"
]) {
  if (!component.includes(requiredKey) && !runner.includes(requiredKey)) {
    failures.push(
      `Lightning Apex payload is missing required key: ${requiredKey}`
    );
  }
}

if (/qualifiedApiName\s*\|\|\s*[^\n]*developerName/.test(component + runner)) {
  failures.push("Lightning contains a QualifiedApiName-to-DeveloperName retry");
}

const prohibitedFallbacks = [
  {
    source: runner,
    pattern:
      /source\s*===\s*["']USER_INITIATED["']\s*\?[^:]+:\s*["']RUN_ON_LOAD["']/,
    message: "Lightning silently coerces an unknown execution source"
  },
  {
    source: formulaEvaluator,
    pattern: /resolveFormulaSingleValue\(formulaExpression,\s*record,\s*null\)/,
    message: "Formula evaluation treats a missing return type as AUTO"
  },
  {
    source: activityCheck,
    pattern: /\?\s*DEFAULT_DAYS_BACK\s*:\s*parsed/,
    message: "Recent-activity configuration silently replaces invalid daysBack"
  },
  {
    source: configService,
    pattern:
      /String\.isBlank\(checkSet\.FoundExpectedDisplay__c\)\s*\?\s*["']ON_DEMAND["']/,
    message: "Check Set comparison display has an implicit runtime default"
  }
];

for (const check of prohibitedFallbacks) {
  if (check.pattern.test(check.source)) {
    failures.push(check.message);
  }
}

for (const requiredContract of [
  [
    constants,
    "throw new IllegalArgumentException",
    "strict Apex enum rejection"
  ],
  [formulaEvaluator, "'INVALID_CONFIG'", "formula return-type rejection"],
  [activityCheck, "unableToEvaluate('INVALID_CONFIG')", "daysBack rejection"],
  [definitionLoader, "Card Title is required", "required Card Title validation"]
]) {
  if (!requiredContract[0].includes(requiredContract[1])) {
    failures.push(`Missing ${requiredContract[2]}`);
  }
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  "Verified exact QualifiedApiName identity, explicit App Builder run scheduling, and strict configuration contracts."
);
