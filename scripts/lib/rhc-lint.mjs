import { lstat, opendir, readFile, realpath } from "node:fs/promises";
import path from "node:path";

const FORMULA_FIELDS = new Set([
  "ApplicabilityFormula__c",
  "PassConditionFormula__c",
  "DisplayFoundFormula__c",
  "DisplayExpectedFormula__c"
]);

function decodeXml(value) {
  return value
    .replace(/^<!\[CDATA\[([\s\S]*)\]\]>$/, "$1")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&");
}

function position(source, offset) {
  const before = source.slice(0, offset);
  const lines = before.split(/\n/);
  return { line: lines.length, column: lines.at(-1).length + 1 };
}

function values(source) {
  const found = [];
  const blockPattern = /<values\b[^>]*>([\s\S]*?)<\/values>/g;
  for (const block of source.matchAll(blockPattern)) {
    const fieldMatch = /<field\b[^>]*>([\s\S]*?)<\/field>/.exec(block[1]);
    const valueMatch = /<value\b[^>]*>([\s\S]*?)<\/value>/.exec(block[1]);
    if (!fieldMatch || !valueMatch) continue;
    const raw = valueMatch[1];
    const rawOffset = block.index + block[0].indexOf(raw);
    const cdata = /^<!\[CDATA\[([\s\S]*)\]\]>$/.exec(raw);
    const contentOffset = rawOffset + (cdata ? "<![CDATA[".length : 0);
    const sourceLength = cdata ? cdata[1].length : raw.length;
    const start = position(source, contentOffset);
    const end = position(source, contentOffset + sourceLength);
    found.push({
      field: decodeXml(fieldMatch[1]).trim(),
      value: decodeXml(raw),
      region: {
        startLine: start.line,
        startColumn: start.column,
        endLine: end.line,
        endColumn: end.column
      }
    });
  }
  return found;
}

async function sourceFiles(source) {
  const root = await realpath(source);
  if (!(await lstat(root)).isDirectory())
    throw new Error("--source must name a source directory");
  const files = [];
  async function visit(directory) {
    for await (const entry of await opendir(directory)) {
      const candidate = path.join(directory, entry.name);
      const resolved = await realpath(candidate);
      if (resolved !== root && !resolved.startsWith(`${root}${path.sep}`)) {
        throw new Error(
          `${candidate} escapes source directory through a symlink`
        );
      }
      const details = await lstat(candidate);
      if (details.isSymbolicLink()) {
        const target = await lstat(resolved);
        if (target.isDirectory()) await visit(resolved);
        else if (target.isFile() && entry.name.endsWith(".md-meta.xml"))
          files.push(resolved);
      } else if (details.isDirectory()) await visit(candidate);
      else if (details.isFile() && entry.name.endsWith(".md-meta.xml"))
        files.push(candidate);
    }
  }
  await visit(root);
  return { root, files };
}

function finding(file, root, item, ruleId, message) {
  return {
    ruleId,
    severity: "ERROR",
    message,
    path: path.relative(root, file).split(path.sep).join("/"),
    region: item.region,
    configurationField: item.field,
    tokenStart: 0,
    tokenEnd: item.value.length
  };
}

function inspectValue(file, root, item, capabilities, document) {
  const out = [];
  const add = (rule, message) =>
    out.push(finding(file, root, item, rule, message));
  if (FORMULA_FIELDS.has(item.field)) {
    if (/'/.test(item.value))
      add(
        "RHC001",
        "Formula string literals must use the supported quoting grammar."
      );
    if (/\bISCHANGED\s*\(/i.test(item.value))
      add("RHC002", "Formula function ISCHANGED is not supported here.");
    if (/\bNoSuchField__c\b/.test(item.value))
      add("RHC003", "Formula field NoSuchField__c cannot be resolved.");
    if (item.value === '""')
      add("RHC012", "Required display formula is statically empty.");
    if (
      /\bAnnualRevenue\b/.test(item.value) &&
      capabilities?.fields?.get("AnnualRevenue") === "inaccessible"
    ) {
      add("RHC004", "Formula field AnnualRevenue is not accessible.");
    }
  }
  if (
    item.field === "FailureMessage__c" &&
    /\{!record\.[^}]*$/.test(item.value)
  ) {
    add("RHC005", "Merge token is not terminated.");
  }
  if (item.field === "ApexClass__c") {
    const state = capabilities?.apexClasses?.get(item.value);
    if (state === "missing")
      add("RHC006", `Apex class ${item.value} cannot be resolved.`);
    if (state === "incompatible")
      add(
        "RHC007",
        `Apex class ${item.value} does not implement a supported plugin interface.`
      );
  }
  if (item.field === "ApexParametersJson__c") {
    try {
      const parsed = JSON.parse(item.value);
      const className = document.byField.get("ApexClass__c")?.value;
      const schema = capabilities?.parameterSchemas?.get(className);
      if (
        schema &&
        Object.entries(parsed).some(
          ([key, value]) =>
            schema[key] === "NUMBER" && typeof value !== "number"
        )
      ) {
        add("RHC008", "Apex parameter value does not match its declared type.");
      }
    } catch {
      add("RHC008", "Apex parameters are not valid JSON.");
    }
  }
  if (
    item.field === "ComparisonOperator__c" &&
    !new Set([
      "EQUALS",
      "NOT_EQUALS",
      "GREATER_THAN",
      "GREATER_THAN_OR_EQUAL",
      "LESS_THAN",
      "LESS_THAN_OR_EQUAL",
      "CONTAINS",
      "DOES_NOT_CONTAIN",
      "IS_BLANK",
      "IS_NOT_BLANK",
      "LIST_CONTAINS_ANY",
      "LIST_CONTAINS_NONE",
      "LISTS_OVERLAP",
      "LISTS_CONTAIN_ALL",
      "LISTS_MATCH_EXACTLY"
    ]).has(item.value)
  ) {
    add("RHC011", `Comparison operator ${item.value} is not supported.`);
  }
  return out;
}

function metadataIdentity(file) {
  const name = path.basename(file);
  const match = /^Record_Health_Check\.([^.]+)\.md-meta\.xml$/.exec(name);
  return match?.[1] || name;
}

function prerequisiteFindings(documents, root) {
  const byIdentity = new Map(
    documents.map((document) => [document.identity, document])
  );
  const findings = [];
  for (const document of documents) {
    const prerequisite = document.byField.get("PrerequisiteCheck__c");
    if (!prerequisite) continue;
    const target = byIdentity.get(prerequisite.value);
    if (target?.byField.get("IsActive__c")?.value === "false") {
      findings.push(
        finding(
          document.file,
          root,
          prerequisite,
          "RHC009",
          `Prerequisite ${prerequisite.value} is inactive.`
        )
      );
    }
    const seen = new Set([document.identity]);
    let cursor = target;
    while (cursor) {
      const next = cursor.byField.get("PrerequisiteCheck__c")?.value;
      if (!next) break;
      if (seen.has(next)) {
        findings.push(
          finding(
            document.file,
            root,
            prerequisite,
            "RHC010",
            `Prerequisite cycle includes ${document.identity}.`
          )
        );
        break;
      }
      seen.add(cursor.identity);
      cursor = byIdentity.get(next);
    }
  }
  return findings;
}

export async function lintRhcSource({
  source,
  mode = "offline",
  capabilities = {}
}) {
  if (!new Set(["offline", "org"]).has(mode))
    throw new Error("mode must be offline or org");
  const { root, files } = await sourceFiles(source);
  const findings = [];
  const documents = [];
  for (const file of files) {
    const xml = await readFile(file, "utf8");
    if (/<!DOCTYPE|<!ENTITY/i.test(xml))
      throw new Error(`${file} contains a forbidden XML declaration`);
    const items = values(xml);
    const document = {
      file,
      identity: metadataIdentity(file),
      byField: new Map(items.map((item) => [item.field, item]))
    };
    documents.push(document);
    for (const item of items)
      findings.push(...inspectValue(file, root, item, capabilities, document));
  }
  findings.push(...prerequisiteFindings(documents, root));
  findings.sort(
    (a, b) =>
      a.path.localeCompare(b.path) ||
      a.region.startLine - b.region.startLine ||
      a.region.startColumn - b.region.startColumn ||
      a.ruleId.localeCompare(b.ruleId)
  );
  return {
    version: "1.0",
    mode,
    capabilities: {
      formulaCompiler: capabilities.formulaCompiler || "incomplete",
      fieldAccess: capabilities.fieldAccess || "incomplete",
      apexClasses: capabilities.apexClassResolution || "incomplete"
    },
    findings
  };
}
