import fs from "node:fs";
import path from "node:path";

const classRoot = "packages/record-health-check/force-app/main/default/classes";
// Measured no-growth ceilings. Existing hotspots are recorded in the Step 10
// review; reductions must lower these values in the same change.
const maxMethodLines = 416;
const maxDecisionPoints = 51;
const approvedProductionRhcNames = new Set([
  "RHCConstructorMutationCheck",
  "RHCDefinitionDependencyIdentity",
  "RHCMetadataDependencyValidator"
]);
const runtimeMatrix = JSON.parse(
  fs.readFileSync("config/release-runtime-matrix.json", "utf8")
);
const expectedExternalEntryClasses = new Set(
  runtimeMatrix.apexExternalEntryClasses ?? []
);
const discoveredExternalEntryClasses = new Set();
const failures = [];
let globalMembers = 0;
let methods = 0;
let approvedSystemModeUses = 0;

function hasAdjacentApexDoc(lines, declarationIndex) {
  let previous = declarationIndex - 1;
  while (previous >= 0 && !lines[previous].trim()) previous--;

  if (previous >= 0 && lines[previous].trim().endsWith(")")) {
    while (previous >= 0 && !lines[previous].trim().startsWith("@")) {
      previous--;
    }
  }
  if (previous >= 0 && lines[previous].trim().startsWith("@")) {
    // Invocable variables carry their externally visible schema documentation
    // in the required label/description annotation itself.
    if (lines[previous].includes("@InvocableVariable")) return true;
    previous--;
    while (previous >= 0 && !lines[previous].trim()) previous--;
  }
  return previous >= 0 && lines[previous].includes("*/");
}

for (const file of fs
  .readdirSync(classRoot)
  .filter((name) => name.endsWith(".cls"))) {
  const className = path.basename(file, ".cls");
  if (className.length > 40) {
    failures.push(
      `${path.join(classRoot, file)}: Apex class name is ${className.length} characters; Salesforce permits at most 40.`
    );
  }
  if (file.includes("Test")) continue;
  const relative = path.join(classRoot, file);
  const source = fs.readFileSync(relative, "utf8");
  const lines = source.split(/\r?\n/);

  if (/\bwithout sharing\b/.test(source)) {
    failures.push(
      `${relative}: production Apex must not declare without sharing.`
    );
  }
  if (
    className === "RecordHealthCheck" ||
    /@AuraEnabled(?:\([^)]*\))?\s+(?:global|public)\s+static\b/s.test(source) ||
    source.includes("@InvocableMethod") ||
    source.includes("@RestResource") ||
    /implements\s+(?:Queueable|Database\.Batchable|Schedulable)\b/.test(
      source
    ) ||
    /extends\s+VisualEditor\.DynamicPickList\b/.test(source)
  ) {
    discoveredExternalEntryClasses.add(className);
  }
  const systemModeUses = (source.match(/\bAccessLevel\.SYSTEM_MODE\b/g) ?? [])
    .length;
  if (systemModeUses > 0) {
    if (file !== "RecordHealthCheckScopePlanner.cls" || systemModeUses !== 1) {
      failures.push(
        `${relative}: SYSTEM_MODE is allowed exactly once, only for package Custom Metadata discovery in RecordHealthCheckScopePlanner.`
      );
    } else {
      approvedSystemModeUses += systemModeUses;
    }
  }

  for (let index = 0; index < lines.length; index++) {
    if (!/^\s*global\s/.test(lines[index])) continue;
    globalMembers++;
    if (!hasAdjacentApexDoc(lines, index)) {
      failures.push(
        `${relative}:${index + 1}: global declaration requires adjacent ApexDoc.`
      );
    }
  }

  if (source.includes("@InvocableMethod")) {
    if (!/\bglobal\s+with sharing class\s+\w+/.test(source)) {
      failures.push(
        `${relative}: a packaged invocable entry point must be a global with-sharing class.`
      );
    }
    if (
      !/@InvocableMethod\s*\([\s\S]*?\)\s*(?:\/\*\*[\s\S]*?\*\/\s*)?global static List</.test(
        source
      )
    ) {
      failures.push(
        `${relative}: a packaged invocable method must be global static for subscriber, Flow, Agentforce, and MCP visibility.`
      );
    }
    for (const typeName of ["Request", "Response"]) {
      if (
        new RegExp(`\\bclass\\s+${typeName}\\b`).test(source) &&
        !new RegExp(`\\bglobal class\\s+${typeName}\\b`).test(source)
      ) {
        failures.push(
          `${relative}: invocable ${typeName} must be global across the managed-package namespace.`
        );
      }
    }
    if (/@InvocableVariable[\s\S]*?\n\s+public\s+\w/.test(source)) {
      failures.push(
        `${relative}: invocable variables must be global across the managed-package namespace.`
      );
    }
    if (/\bpublic class\s+\w+/.test(source)) {
      failures.push(
        `${relative}: nested invocable contract types must not remain package-private public types.`
      );
    }
  }

  if (source.includes("@RestResource")) {
    if (!/\bglobal\s+with sharing class\s+\w+/.test(source)) {
      failures.push(
        `${relative}: a packaged REST entry point must be a global with-sharing class.`
      );
    }
    if (
      !/@Http(?:Get|Post|Put|Patch|Delete)[\s\S]*?global static\s+/.test(source)
    ) {
      failures.push(
        `${relative}: a packaged REST handler must be a global static method.`
      );
    }
  }

  if (
    /implements\s+(?:Queueable|Database\.Batchable|Schedulable)\b/.test(
      source
    ) &&
    !/\bglobal\s+with sharing class\s+\w+/.test(source)
  ) {
    failures.push(
      `${relative}: a packaged asynchronous entry point must be a global with-sharing class.`
    );
  }

  const topLevelName = source.match(
    /\b(?:global|public)\s+(?:(?:with|without|inherited)\s+sharing\s+)?class\s+(RHC\w+)/
  )?.[1];
  if (topLevelName && !approvedProductionRhcNames.has(topLevelName)) {
    failures.push(
      `${relative}: production RHC-prefixed type requires a compatibility decision.`
    );
  }

  for (let start = 0; start < lines.length; start++) {
    const openingParen = lines[start].indexOf("(");
    if (
      !/^\s*(?:global|public|private|protected)\b/.test(lines[start]) ||
      openingParen < 0 ||
      lines[start].slice(0, openingParen).includes("=") ||
      /\b(?:class|interface|enum)\b/.test(lines[start])
    )
      continue;
    let signatureEnd = start;
    while (signatureEnd < lines.length && !lines[signatureEnd].includes("{"))
      signatureEnd++;
    if (signatureEnd >= lines.length) continue;
    let depth = 0;
    let end = signatureEnd;
    for (; end < lines.length; end++) {
      depth += (lines[end].match(/\{/g) ?? []).length;
      depth -= (lines[end].match(/\}/g) ?? []).length;
      if (depth === 0) break;
    }
    const body = lines.slice(signatureEnd, end + 1).join("\n");
    const length = end - start + 1;
    const decisions = (
      body.match(/\b(?:if|else\s+if|for|while|catch)\b|&&|\|\||\?/g) ?? []
    ).length;
    methods++;
    if (length > maxMethodLines)
      failures.push(
        `${relative}:${start + 1}: method is ${length} lines; maximum is ${maxMethodLines}.`
      );
    if (decisions > maxDecisionPoints)
      failures.push(
        `${relative}:${start + 1}: method has ${decisions} decision points; maximum is ${maxDecisionPoints}.`
      );
    start = end;
  }
}

if (approvedSystemModeUses !== 1) {
  failures.push(
    `Expected exactly one reviewed Custom Metadata SYSTEM_MODE query; found ${approvedSystemModeUses}.`
  );
}
const missingExternalEntries = [...expectedExternalEntryClasses].filter(
  (className) => !discoveredExternalEntryClasses.has(className)
);
const unreviewedExternalEntries = [...discoveredExternalEntryClasses].filter(
  (className) => !expectedExternalEntryClasses.has(className)
);
if (missingExternalEntries.length > 0 || unreviewedExternalEntries.length > 0) {
  failures.push(
    `External Apex entry-point inventory drifted. Missing: ${missingExternalEntries.join(", ") || "none"}; unreviewed: ${unreviewedExternalEntries.join(", ") || "none"}.`
  );
}

if (failures.length) {
  console.error("Apex surface policy failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log(
  `Apex surface policy passed: ${globalMembers} global declarations documented; ${methods} methods checked (max ${maxMethodLines} lines / ${maxDecisionPoints} decisions).`
);
