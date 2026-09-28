#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const docsRoot = path.join(root, "docs");
const metadataRoot = path.join(
  root,
  "packages/record-health-check/force-app/main/default"
);
const failures = [];

function markdownFiles(directory) {
  const output = [];
  function walk(current) {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const absolute = path.join(current, entry.name);
      if (entry.isDirectory()) walk(absolute);
      else if (entry.name.endsWith(".md")) output.push(absolute);
    }
  }
  walk(directory);
  return output.sort();
}

function read(relative) {
  return fs.readFileSync(path.join(root, relative), "utf8");
}

function xmlValue(source, name) {
  return (
    source
      .match(new RegExp(`<${name}\\b[^>]*>([\\s\\S]*?)</${name}>`))?.[1]
      ?.trim() ?? ""
  );
}

const pages = markdownFiles(docsRoot);
const allDocs = pages.map((file) => fs.readFileSync(file, "utf8")).join("\n");
const explanatoryDocs = pages
  .filter((file) => !file.endsWith("source-inventory.md"))
  .map((file) => fs.readFileSync(file, "utf8"))
  .join("\n");
const permissionReference = read("docs/reference/permission-sets.md");
const customPermissionReference = read("docs/reference/custom-permissions.md");
const featureCatalog = read("docs/reference/feature-catalog.md");
const flowReference = read("docs/flow-guides/action-inputs-and-outputs.md");
const agentforceReference = read(
  "docs/developer-guides/agentforce-and-mcp/agentforce-actions.md"
);
const apexReference = read("docs/developer-guides/run-from-apex.md");
const readinessReference = read("docs/reference/readiness-receipts.md");
const previewGuide = read(
  "docs/build-checks/draft-with-ai/validate-and-preview-an-ai-draft.md"
);
const diagnosticsGuide = read("docs/diagnostics/browser-console.md");
const securityReference = read("docs/architecture/security-and-data-access.md");
const integrationReference = read(
  "docs/developer-guides/integration-options.md"
);
const lightningComponentGuide = read(
  "docs/lightning-record-page/configure-the-component.md"
);
const objectFieldReferences = new Map([
  [
    "Record_Health_Check__mdt",
    read("docs/reference/custom-metadata/check-fields.md")
  ],
  [
    "Record_Health_Check_Set__mdt",
    read("docs/reference/custom-metadata/check-set-fields.md")
  ],
  ["Record_Health_Check_Readiness__c", readinessReference],
  [
    "Record_Health_Check_Log__e",
    read("docs/reference/platform-event-metadata/error-log.md")
  ],
  [
    "Record_Health_Check_Result__e",
    read("docs/reference/platform-event-metadata/check-result.md")
  ],
  [
    "Record_Health_Check_Set_Run__e",
    read("docs/reference/platform-event-metadata/check-set-run.md")
  ]
]);

for (const [phrase, correction] of [
  ["six Permission Sets", "seven Permission Sets"],
  ["Six Permission Sets", "Seven Permission Sets"],
  ["two Custom Permissions", "one Custom Permission"],
  ["two Flow actions", "three Flow actions"],
  ["installed managed package", "installed unlocked package"]
]) {
  if (allDocs.includes(phrase)) {
    failures.push(
      `Canonical documentation still says '${phrase}'; use '${correction}'.`
    );
  }
}

const permissionDirectory = path.join(metadataRoot, "permissionsets");
const permissionFiles = fs
  .readdirSync(permissionDirectory)
  .filter((name) => name.endsWith(".permissionset-meta.xml"));
for (const name of permissionFiles) {
  const source = fs.readFileSync(path.join(permissionDirectory, name), "utf8");
  const label = xmlValue(source, "label");
  const apiName = name.replace(".permissionset-meta.xml", "");
  if (!permissionReference.includes(`**${label}**`)) {
    failures.push(
      `Permission Set reference is missing Salesforce label '${label}'.`
    );
  }
  if (
    !permissionReference.includes(`\`${apiName}\``) &&
    !permissionReference.includes(`\`rhc__${apiName}\``)
  ) {
    failures.push(`Permission Set reference is missing API name '${apiName}'.`);
  }
}

const customPermissionDirectory = path.join(metadataRoot, "customPermissions");
for (const name of fs
  .readdirSync(customPermissionDirectory)
  .filter((entry) => entry.endsWith(".customPermission-meta.xml"))) {
  const source = fs.readFileSync(
    path.join(customPermissionDirectory, name),
    "utf8"
  );
  const label = xmlValue(source, "label");
  const apiName = name.replace(".customPermission-meta.xml", "");
  if (
    !customPermissionReference.includes(label) ||
    (!customPermissionReference.includes(`\`${apiName}\``) &&
      !customPermissionReference.includes(`\`rhc__${apiName}\``))
  ) {
    failures.push(
      `Custom Permission reference is missing '${label}' (${apiName}).`
    );
  }
}

const lwcRoot = path.join(metadataRoot, "lwc");
for (const entry of fs.readdirSync(lwcRoot, { withFileTypes: true })) {
  if (!entry.isDirectory()) continue;
  const metadataFile = path.join(
    lwcRoot,
    entry.name,
    `${entry.name}.js-meta.xml`
  );
  if (!fs.existsSync(metadataFile)) continue;
  const source = fs.readFileSync(metadataFile, "utf8");
  if (xmlValue(source, "isExposed") !== "true") continue;
  const label = xmlValue(source, "masterLabel");
  if (!featureCatalog.includes(label)) {
    failures.push(
      `Feature catalog is missing exposed Lightning component '${label}'.`
    );
  }
  for (const property of source.matchAll(/<property\b([\s\S]*?)\/>/g)) {
    const propertyLabel = property[1].match(/label="([^"]+)"/)?.[1];
    if (propertyLabel && !lightningComponentGuide.includes(propertyLabel)) {
      failures.push(
        `Lightning component guide is missing App Builder property '${propertyLabel}'.`
      );
    }
  }
}

const classRoot = path.join(metadataRoot, "classes");
const globalApexTypes = [];
for (const name of fs
  .readdirSync(classRoot)
  .filter((entry) => entry.endsWith(".cls"))) {
  const source = fs.readFileSync(path.join(classRoot, name), "utf8");
  const globalType = source.match(
    /^global\s+(?:(?:with|without|inherited)\s+sharing\s+)?(?:abstract\s+class|class|interface|enum)\s+(\w+)/m
  )?.[1];
  if (globalType) {
    globalApexTypes.push(globalType);
    if (!explanatoryDocs.includes(globalType)) {
      failures.push(
        `Canonical documentation is missing global Apex type '${globalType}'.`
      );
    }
  }
  if (!source.includes("@InvocableMethod")) continue;
  const annotation =
    source.match(/@InvocableMethod\s*\(([\s\S]*?)\)/)?.[1] ?? "";
  const label = annotation.match(/label='([^']+)'/)?.[1];
  const target = name.includes("AgentAction")
    ? agentforceReference
    : flowReference;
  if (label && !target.includes(label)) {
    failures.push(
      `${name}: canonical documentation is missing the invocable action label '${label}'.`
    );
  }
  for (const variable of source.matchAll(
    /@InvocableVariable\s*(?:\(([\s\S]*?)\))?\s*global\s+[A-Za-z0-9_<>,.]+\s+(\w+)\s*;/g
  )) {
    const variableLabel =
      variable[1]?.match(/label='([^']+)'/)?.[1] ?? variable[2];
    if (!target.includes(variableLabel)) {
      failures.push(
        `${name}: canonical documentation is missing invocable input/output label '${variableLabel}'.`
      );
    }
  }
}

for (const method of [
  "forCheck(",
  "forCheckSet(",
  "withResultMode(",
  "withEventPublication(",
  "withRunId(",
  "withExecutionOrigin(",
  "withDiagnosticContractVersion("
]) {
  if (!apexReference.includes(method)) {
    failures.push(`Apex request reference is missing '${method}'.`);
  }
}

for (const [surface, reference, terms] of [
  [
    "Preview",
    previewGuide,
    [
      "Record Health Check Preview",
      "VALIDATE_ONLY",
      "EXECUTE",
      "readiness receipt",
      "does not save",
      "never publishes"
    ]
  ],
  [
    "diagnostics",
    diagnosticsGuide,
    [
      "Show Diagnostics",
      "Record Health Check Diagnostics Viewer",
      "Record Health Check Admin",
      "Diagnostic ID",
      "Support report",
      "does not grant record or field access"
    ]
  ],
  [
    "security",
    securityReference,
    [
      "Record Health Check Run",
      "user mode",
      "with sharing",
      "Lightning card",
      "Flow",
      "Apex",
      "Queueable Apex",
      "Batch Apex",
      "Scheduled Apex",
      "Agentforce",
      "REST",
      "Platform Events"
    ]
  ],
  [
    "supported entry points",
    integrationReference,
    [
      "Lightning component",
      "Flow actions",
      "direct Apex API",
      "Queueable",
      "Batch",
      "Scheduled Apex",
      "Agentforce actions",
      "MCP service",
      "REST API",
      "Platform Event"
    ]
  ]
]) {
  for (const term of terms) {
    if (!reference.toLowerCase().includes(term.toLowerCase())) {
      failures.push(`${surface} documentation is missing '${term}'.`);
    }
  }
}

for (const capability of [
  "Record Health Check Preview",
  "Diagnostic contract 2.0",
  "Readiness receipts",
  "Lightning record page",
  "Flow",
  "Synchronous Apex",
  "Queueable Apex",
  "Batch Apex",
  "Scheduled Apex",
  "Agentforce",
  "REST agent tool",
  "MCP service",
  "Platform Events"
]) {
  if (!featureCatalog.toLowerCase().includes(capability.toLowerCase())) {
    failures.push(`Feature catalog is missing '${capability}'.`);
  }
}

const objectRoot = path.join(metadataRoot, "objects");
for (const [objectApiName, reference] of objectFieldReferences) {
  const fieldDirectory = path.join(objectRoot, objectApiName, "fields");
  if (!explanatoryDocs.includes(`\`${objectApiName}\``)) {
    failures.push(
      `Canonical documentation is missing object '${objectApiName}'.`
    );
  }
  for (const name of fs
    .readdirSync(fieldDirectory)
    .filter((entry) => entry.endsWith(".field-meta.xml"))) {
    const apiName = name.replace(".field-meta.xml", "");
    if (!reference.includes(`\`${apiName}\``)) {
      failures.push(
        `${objectApiName} reference is missing field '${apiName}'.`
      );
    }
  }
}

for (const file of pages) {
  if (
    /\bAudience:|\bThe audience is\b|^\|[^\n]*\bAudience\b[^\n]*\|\s*\n\|[ :|-]+\||\bThis (?:guide|page) is for\b|\bpersonas?\b/im.test(
      fs.readFileSync(file, "utf8")
    )
  ) {
    failures.push(
      `${path.relative(root, file)}: route by Salesforce task instead of an audience or persona label.`
    );
  }
}

const examplesRoot = path.join(docsRoot, "examples");
const workedExamples = markdownFiles(examplesRoot).filter(
  (file) =>
    path.basename(file) !== "README.md" &&
    ["formula", "query", "compare-two-queries", "apex"].includes(
      path.basename(path.dirname(file))
    )
);
for (const file of workedExamples) {
  const markdown = fs.readFileSync(file, "utf8");
  const relative = path.relative(root, file);
  for (const heading of [
    "## Why this pattern fits",
    "## Before you configure it",
    "## Step 1: Create or choose the Check Set",
    "## Step 2: Create the Check",
    "## Step 3: Validate and activate",
    "## Step 4: Test the result",
    "## If it does not work",
    "## Technical reference"
  ]) {
    if (!markdown.includes(heading)) {
      failures.push(
        `${relative}: missing required example section '${heading}'.`
      );
    }
  }
  if (
    /^\| *(?:Setup field|Salesforce field) *\| *API name *\|/im.test(markdown)
  ) {
    failures.push(`${relative}: keep API-name tables in technical references.`);
  }
  const inactiveMatch = markdown.match(/^\|\s*Active\s*\|\s*Unchecked\b/im);
  const inactive = inactiveMatch?.index ?? -1;
  const validate = markdown.indexOf("## Step 3: Validate and activate");
  const validationSteps = validate === -1 ? "" : markdown.slice(validate);
  const activationInstruction = validationSteps.match(
    /(?:set[^\n]*\*\*Active\*\*|activate[^\n]*(?:Check|checks))/i
  );
  const activate =
    activationInstruction && validate !== -1
      ? validate + activationInstruction.index
      : -1;
  if (
    inactive === -1 ||
    validate === -1 ||
    activate === -1 ||
    inactive > validate
  ) {
    failures.push(`${relative}: save inactive, validate, and then activate.`);
  }
  if (!markdown.includes("Record Health Check Card User")) {
    failures.push(`${relative}: test with Record Health Check Card User.`);
  }
}

if (!/!\[[^\]]+\]\([^)]+\)/.test(allDocs)) {
  failures.push(
    "Canonical documentation needs at least one maintained visual with alternative text."
  );
}

const firstCheck = read("docs/step-by-step-guide/create-your-first-check.md");
const firstActiveMatch = firstCheck.match(/^\|\s*Active\s*\|\s*Unchecked\b/im);
const firstActive = firstActiveMatch?.index ?? -1;
const validation = firstCheck.indexOf("## Step 3: Validate before activation");
const firstValidationSteps =
  validation === -1 ? "" : firstCheck.slice(validation);
const firstActivationInstruction =
  firstValidationSteps.match(/check \*\*Active\*\*/i);
const activation =
  firstActivationInstruction && validation !== -1
    ? validation + firstActivationInstruction.index
    : -1;
if (
  firstActive === -1 ||
  validation === -1 ||
  activation === -1 ||
  !(firstActive < validation && validation < activation)
) {
  failures.push(
    "The first Check guide must save inactive, validate, and only then activate."
  );
}

const configurationGuide = read(
  "docs/build-checks/configure-check-sets-and-checks.md"
);
const configurationInactiveMatch = configurationGuide.match(
  /^\|\s*\*\*Active\*\*\s*\|\s*Unchecked while building\b/im
);
const configurationInactive = configurationInactiveMatch?.index ?? -1;
const configurationValidation = configurationGuide.indexOf(
  "## Step 7: Validate and activate"
);
const configurationActivationMatch = configurationGuide
  .slice(Math.max(configurationValidation, 0))
  .match(/select \*\*Active\*\*/i);
const configurationActivation =
  configurationValidation !== -1 && configurationActivationMatch
    ? configurationValidation + configurationActivationMatch.index
    : -1;
const configurationTesting = configurationGuide.indexOf(
  "## Step 10: Test before rollout"
);
if (
  configurationInactive === -1 ||
  configurationValidation === -1 ||
  configurationActivation === -1 ||
  configurationTesting === -1 ||
  !(
    configurationInactive < configurationValidation &&
    configurationValidation < configurationActivation &&
    configurationActivation < configurationTesting
  )
) {
  failures.push(
    "The complete configuration guide must save inactive, validate, activate, and then test before rollout."
  );
}

if (failures.length) {
  console.error("Documentation semantics failed:\n- " + failures.join("\n- "));
  process.exit(1);
}

console.log(
  `Documentation semantic coverage passed for ${permissionFiles.length} Permission Sets, exposed LWCs, invocable actions, ${globalApexTypes.length} global Apex types, public request options, Preview, readiness, diagnostics, security, supported entry points, every field on ${objectFieldReferences.size} packaged data definitions, ${workedExamples.length} progressive examples, task-first language, and visual guidance.`
);
