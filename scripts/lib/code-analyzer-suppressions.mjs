export const EXPECTED_CODE_ANALYZER_SUPPRESSIONS = new Map([
  [
    "packages/record-health-check/force-app/main/default/objects/Record_Health_Check_Set__mdt/fields/PassedChecksDisplay__c.field-meta.xml",
    "pmd:ProtectSensitiveData"
  ],
  [
    "packages/record-health-check/force-app/main/default/objects/Record_Health_Check__mdt/fields/PassConditionFormula__c.field-meta.xml",
    "pmd:ProtectSensitiveData"
  ],
  [
    "packages/record-health-check/integration-tests/main/default/objects/RHC_Benchmark_Result__c/fields/Passed__c.field-meta.xml",
    "pmd:ProtectSensitiveData"
  ],
  [
    "packages/record-health-check/integration-tests/main/default/objects/RHC_Persona_Record__c/fields/Accessible_Value__c.field-meta.xml",
    "pmd:ProtectSensitiveData"
  ]
]);

function suppressionSection(source) {
  const lines = source.split(/\r?\n/);
  const start = lines.findIndex((line) => line.trim() === "suppressions:");
  if (start < 0) return null;

  let end = lines.length;
  for (let index = start + 1; index < lines.length; index += 1) {
    if (/^[A-Za-z][A-Za-z0-9_-]*:\s*(?:#.*)?$/.test(lines[index])) {
      end = index;
      break;
    }
  }
  return lines.slice(start + 1, end);
}

function parseSuppressions(lines) {
  const entries = new Map();
  let currentPath = null;

  for (const line of lines) {
    const pathMatch = line.match(/^  ["']([^"']+)["']:\s*$/);
    if (pathMatch) {
      currentPath = pathMatch[1];
      entries.set(currentPath, { rules: [], maximums: [], reasons: [] });
      continue;
    }
    if (!currentPath) continue;

    const ruleMatch = line.match(/^\s+- rule_selector:\s*["']([^"']+)["']\s*$/);
    if (ruleMatch) entries.get(currentPath).rules.push(ruleMatch[1]);

    const maximumMatch = line.match(
      /^\s+max_suppressed_violations:\s*(\d+)\s*$/
    );
    if (maximumMatch) {
      entries.get(currentPath).maximums.push(Number(maximumMatch[1]));
    }

    const reasonMatch = line.match(/^\s+reason:\s*["'](.+)["']\s*$/);
    if (reasonMatch) entries.get(currentPath).reasons.push(reasonMatch[1]);
  }

  return entries;
}

export function codeAnalyzerSuppressionErrors(source) {
  const errors = [];
  const section = suppressionSection(source);
  if (!section) return ["code-analyzer.yml has no suppressions section"];

  const actual = parseSuppressions(section);
  for (const path of actual.keys()) {
    if (!EXPECTED_CODE_ANALYZER_SUPPRESSIONS.has(path)) {
      errors.push(`unapproved suppression path: ${path}`);
    }
  }

  for (const [path, expectedRule] of EXPECTED_CODE_ANALYZER_SUPPRESSIONS) {
    const entry = actual.get(path);
    if (!entry) {
      errors.push(`missing approved suppression: ${path}`);
      continue;
    }
    if (entry.rules.length !== 1 || entry.rules[0] !== expectedRule) {
      errors.push(`${path} must suppress only ${expectedRule}`);
    }
    if (entry.maximums.length !== 1 || entry.maximums[0] !== 1) {
      errors.push(`${path} must cap suppressed violations at exactly 1`);
    }
    if (entry.reasons.length !== 1 || entry.reasons[0].trim().length < 20) {
      errors.push(`${path} must contain one specific suppression reason`);
    }
  }

  if (/ProtectSensitiveData:\s*[\s\S]{0,240}?disabled:\s*true\b/.test(source)) {
    errors.push("ProtectSensitiveData must not be disabled globally");
  }

  return errors;
}
