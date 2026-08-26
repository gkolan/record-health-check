import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const DEFAULT = path.join(
  ROOT,
  "packages/record-health-check/force-app",
  "main",
  "default"
);
const PERMISSION_SETS = path.join(DEFAULT, "permissionsets");
const MAX_SALESFORCE_DESCRIPTION = 255;
const PROJECT_DESCRIPTION_BUDGET = 200;

const expected = {
  Record_Health_Check_Admin: {
    classes: [
      "RecordHealthCheck",
      "RecordHealthCheckAgentRestResource",
      "RecordHealthCheckBatch",
      "RecordHealthCheckController",
      "RecordHealthCheckMetadataValidator",
      "RecordHealthCheckValidateMetadataAction",
      "RecordHealthCheckRunCheckAgentAction",
      "RecordHealthCheckRunCheckFlowAction",
      "RecordHealthCheckRunSetAgentAction",
      "RecordHealthCheckRunSetFlowAction",
      "RecordHealthCheckQueueable",
      "RecordHealthCheckScheduled",
      "RecordHealthCheckSetPicklist"
    ],
    objects: [
      "Record_Health_Check_Result__e",
      "Record_Health_Check_Set_Run__e"
    ],
    customPermissions: [
      "Record_Health_Check_Run",
      "Record_Health_Check_View_Diagnostics"
    ],
    tabs: [],
    customMetadataTypes: [
      "Record_Health_Check__mdt",
      "Record_Health_Check_Set__mdt"
    ]
  },
  Record_Health_Check_User: {
    classes: [
      "RecordHealthCheck",
      "RecordHealthCheckAgentRestResource",
      "RecordHealthCheckBatch",
      "RecordHealthCheckController",
      "RecordHealthCheckRunCheckAgentAction",
      "RecordHealthCheckRunCheckFlowAction",
      "RecordHealthCheckRunSetAgentAction",
      "RecordHealthCheckRunSetFlowAction",
      "RecordHealthCheckQueueable",
      "RecordHealthCheckScheduled",
      "RecordHealthCheckSetPicklist"
    ],
    objects: [
      "Record_Health_Check_Result__e",
      "Record_Health_Check_Set_Run__e"
    ],
    customPermissions: ["Record_Health_Check_Run"],
    tabs: [],
    customMetadataTypes: [
      "Record_Health_Check__mdt",
      "Record_Health_Check_Set__mdt"
    ]
  },
  Record_Health_Check_Card_User: {
    classes: ["RecordHealthCheckController", "RecordHealthCheckSetPicklist"],
    objects: [
      "Record_Health_Check_Result__e",
      "Record_Health_Check_Set_Run__e"
    ],
    customPermissions: ["Record_Health_Check_Run"],
    customMetadataTypes: [],
    tabs: []
  },
  Record_Health_Check_MCP_Integration: {
    classes: ["RecordHealthCheckAgentRestResource"],
    objects: [],
    customPermissions: ["Record_Health_Check_Run"],
    tabs: [],
    customMetadataTypes: [
      "Record_Health_Check__mdt",
      "Record_Health_Check_Set__mdt"
    ]
  },
  Record_Health_Check_Error_Log_Publisher: {
    classes: [],
    objects: ["Record_Health_Check_Log__e"],
    customPermissions: [],
    customMetadataTypes: [],
    tabs: []
  }
};

const values = (xml, tag) =>
  [...xml.matchAll(new RegExp(`<${tag}>([^<]+)<\\/${tag}>`, "g"))].map(
    (match) => match[1].trim()
  );
const blockValues = (xml, block, tag) =>
  [...xml.matchAll(new RegExp(`<${block}>([\\s\\S]*?)<\\/${block}>`, "g"))]
    .map(
      (match) => match[1].match(new RegExp(`<${tag}>([^<]+)<\\/${tag}>`))?.[1]
    )
    .filter(Boolean)
    .map((value) => value.trim());
const blocks = (xml, block) =>
  [...xml.matchAll(new RegExp(`<${block}>([\\s\\S]*?)<\\/${block}>`, "g"))].map(
    (match) => match[1]
  );
const childValue = (block, tag) =>
  block.match(new RegExp(`<${tag}>([^<]+)<\\/${tag}>`))?.[1].trim();
const sorted = (items) => [...items].sort();
const same = (left, right) =>
  JSON.stringify(sorted(left)) === JSON.stringify(sorted(right));
const errors = [];
const allowedTopLevelElements = new Set([
  "label",
  "description",
  "hasActivationRequired",
  "classAccesses",
  "customPermissions",
  "customMetadataTypeAccesses",
  "objectPermissions",
  "tabSettings"
]);

function topLevelElements(xml) {
  const elements = [];
  let depth = 0;
  for (const match of xml.matchAll(
    /<\/?([A-Za-z][A-Za-z0-9]*)(?:\s[^<>]*?)?\/?>/g
  )) {
    const token = match[0];
    const name = match[1];
    if (token.startsWith("</")) {
      depth--;
      continue;
    }
    if (depth === 1) elements.push(name);
    if (!token.endsWith("/>")) depth++;
  }
  return elements;
}

function validateEnabledBlocks(name, xml, blockName, identityTag) {
  for (const block of blocks(xml, blockName)) {
    const identity = childValue(block, identityTag) ?? "unknown";
    if (childValue(block, "enabled") !== "true") {
      errors.push(`${name} ${blockName} ${identity} must be enabled.`);
    }
    const allowedTags = new Set([identityTag, "enabled"]);
    for (const match of block.matchAll(/<([A-Za-z][A-Za-z0-9]*)>/g)) {
      if (!allowedTags.has(match[1])) {
        errors.push(
          `${name} ${blockName} ${identity} contains unexpected field ${match[1]}.`
        );
      }
    }
  }
}

function validateObjectBlocks(name, xml) {
  const expectedBooleans = {
    allowCreate: "true",
    allowDelete: "false",
    allowEdit: "false",
    allowRead: "true",
    modifyAllRecords: "false",
    viewAllRecords: "false"
  };
  const allowedTags = new Set([
    ...Object.keys(expectedBooleans),
    "object",
    "viewAllFields"
  ]);
  for (const block of blocks(xml, "objectPermissions")) {
    const objectName = childValue(block, "object") ?? "unknown";
    for (const [tag, expectedValue] of Object.entries(expectedBooleans)) {
      if (childValue(block, tag) !== expectedValue) {
        errors.push(
          `${name} object ${objectName} must set ${tag}=${expectedValue}.`
        );
      }
    }
    if (
      childValue(block, "viewAllFields") !== undefined &&
      childValue(block, "viewAllFields") !== "false"
    ) {
      errors.push(`${name} object ${objectName} must not grant viewAllFields.`);
    }
    for (const match of block.matchAll(/<([A-Za-z][A-Za-z0-9]*)>/g)) {
      if (!allowedTags.has(match[1])) {
        errors.push(
          `${name} object ${objectName} contains unexpected field ${match[1]}.`
        );
      }
    }
  }
}

for (const [name, contract] of Object.entries(expected)) {
  const file = path.join(PERMISSION_SETS, `${name}.permissionset-meta.xml`);
  if (!fs.existsSync(file)) {
    errors.push(`Missing permission set: ${name}`);
    continue;
  }
  const xml = fs.readFileSync(file, "utf8");
  const description =
    xml.match(/<description\s*>([\s\S]*?)<\/description>/)?.[1].trim() ?? "";
  if (description.length > MAX_SALESFORCE_DESCRIPTION) {
    errors.push(
      `${name} description exceeds Salesforce's ${MAX_SALESFORCE_DESCRIPTION}-character limit (${description.length}).`
    );
  } else if (description.length > PROJECT_DESCRIPTION_BUDGET) {
    errors.push(
      `${name} description exceeds the project's ${PROJECT_DESCRIPTION_BUDGET}-character safety budget (${description.length}).`
    );
  }
  if (childValue(xml, "hasActivationRequired") !== "false") {
    errors.push(`${name} must set hasActivationRequired=false.`);
  }
  for (const elementName of topLevelElements(xml)) {
    if (!allowedTopLevelElements.has(elementName)) {
      errors.push(
        `${name} contains unexpected privilege block ${elementName}.`
      );
    }
  }
  validateEnabledBlocks(name, xml, "classAccesses", "apexClass");
  validateEnabledBlocks(name, xml, "customPermissions", "name");
  validateEnabledBlocks(name, xml, "customMetadataTypeAccesses", "name");
  validateObjectBlocks(name, xml);

  const actualClasses = values(xml, "apexClass");
  const actualObjects = values(xml, "object");
  const actualCustomPermissions = blockValues(xml, "customPermissions", "name");
  const actualCustomMetadataTypes = blockValues(
    xml,
    "customMetadataTypeAccesses",
    "name"
  );
  const actualTabs = blockValues(xml, "tabSettings", "tab");
  if (!same(actualClasses, contract.classes))
    errors.push(`${name} Apex class access is out of date.`);
  if (!same(actualObjects, contract.objects))
    errors.push(`${name} object access is out of date.`);
  if (!same(actualCustomPermissions, contract.customPermissions))
    errors.push(`${name} custom permission access is out of date.`);
  if (!same(actualCustomMetadataTypes, contract.customMetadataTypes))
    errors.push(`${name} custom metadata access is out of date.`);
  if (!same(actualTabs, contract.tabs))
    errors.push(`${name} tab visibility is out of date.`);
  for (const block of blocks(xml, "tabSettings")) {
    const tab = childValue(block, "tab") ?? "unknown";
    if (childValue(block, "visibility") !== "Visible") {
      errors.push(`${name} tab ${tab} must be Visible.`);
    }
    for (const match of block.matchAll(/<([A-Za-z][A-Za-z0-9]*)>/g)) {
      if (!new Set(["tab", "visibility"]).has(match[1])) {
        errors.push(
          `${name} tab ${tab} contains unexpected field ${match[1]}.`
        );
      }
    }
  }

  for (const apexClass of actualClasses) {
    if (!fs.existsSync(path.join(DEFAULT, "classes", `${apexClass}.cls`)))
      errors.push(`${name} references missing Apex class ${apexClass}.`);
  }
  for (const objectName of actualObjects) {
    if (
      !fs.existsSync(
        path.join(
          DEFAULT,
          "objects",
          objectName,
          `${objectName}.object-meta.xml`
        )
      )
    )
      errors.push(`${name} references missing object ${objectName}.`);
  }
  for (const permission of actualCustomPermissions) {
    if (
      !fs.existsSync(
        path.join(
          DEFAULT,
          "customPermissions",
          `${permission}.customPermission-meta.xml`
        )
      )
    )
      errors.push(
        `${name} references missing custom permission ${permission}.`
      );
  }
}

const actualNames = fs
  .readdirSync(PERMISSION_SETS)
  .map((file) => file.replace(".permissionset-meta.xml", ""));
for (const name of actualNames) {
  if (!expected[name])
    errors.push(`Permission set ${name} has no audited access contract.`);
}

if (errors.length) {
  console.error(errors.join("\n"));
  process.exitCode = 1;
} else {
  console.log(
    `Verified ${actualNames.length} permission sets; descriptions, enabled flags, object CRUD, the top-level privilege allowlist, and access contracts are current.`
  );
}
