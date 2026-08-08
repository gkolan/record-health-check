import fs from "node:fs";
import path from "node:path";

const roots = [
  path.resolve("packages/record-health-check/force-app/main/default/classes"),
  path.resolve(
    "packages/record-health-check/integration-tests/main/default/classes"
  )
];
const methods = new Map([
  ["Account", "RecordHealthCheckTestDataFactory.account"],
  ["Contact", "RecordHealthCheckTestDataFactory.contact"],
  ["Opportunity", "RecordHealthCheckTestDataFactory.opportunity"],
  ["Task", "RecordHealthCheckTestDataFactory.task"],
  ["Event", "RecordHealthCheckTestDataFactory.event"],
  ["Case", "RecordHealthCheckTestDataFactory.caseRecord"],
  ["User", "RecordHealthCheckTestDataFactory.user"],
  ["Record_Health_Check__mdt", "RecordHealthCheckTestDataFactory.check"],
  ["Record_Health_Check_Set__mdt", "RecordHealthCheckTestDataFactory.checkSet"],
  ["RHC_Benchmark_Result__c", "RHCIntegrationTestDataFactory.benchmarkResult"],
  ["RHC_Event_Export__c", "RHCIntegrationTestDataFactory.eventExport"]
]);
const constructor = new RegExp(
  `\\bnew\\s+(${[...methods.keys()].join("|")})\\s*\\(`,
  "g"
);

function scanUntilClose(source, openIndex) {
  let depth = 1;
  let quote = null;
  for (let index = openIndex + 1; index < source.length; index += 1) {
    const character = source[index];
    if (quote) {
      if (character === "\\") index += 1;
      else if (character === quote) quote = null;
      continue;
    }
    if (character === "'" || character === '"') quote = character;
    else if (character === "(") depth += 1;
    else if (character === ")" && --depth === 0) return index;
  }
  throw new Error(`Unclosed constructor at offset ${openIndex}`);
}

function splitFields(body) {
  const values = [];
  let start = 0;
  let round = 0;
  let square = 0;
  let curly = 0;
  let quote = null;
  for (let index = 0; index < body.length; index += 1) {
    const character = body[index];
    if (quote) {
      if (character === "\\") index += 1;
      else if (character === quote) quote = null;
      continue;
    }
    if (character === "'" || character === '"') quote = character;
    else if (character === "(") round += 1;
    else if (character === ")") round -= 1;
    else if (character === "[") square += 1;
    else if (character === "]") square -= 1;
    else if (character === "{") curly += 1;
    else if (character === "}") curly -= 1;
    else if (character === "," && round === 0 && square === 0 && curly === 0) {
      values.push(body.slice(start, index));
      start = index + 1;
    }
  }
  values.push(body.slice(start));
  return values.filter((value) => value.trim());
}

function convertBody(type, body, file) {
  const fields = splitFields(body);
  const method = methods.get(type);
  if (!fields.length) return `${method}(new Map<String, Object>())`;
  const converted = fields.map((field) => {
    const match = field.match(
      /^(\s*)([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([\s\S]*?)\s*$/
    );
    if (!match)
      throw new Error(`${file}: unsupported ${type} field: ${field.trim()}`);
    return `${match[1]}'${match[2]}' => ${match[3]}`;
  });
  return `${method}(new Map<String, Object>{${converted.join(",")}})`;
}

for (const root of roots) {
  for (const fileName of fs.readdirSync(root).sort()) {
    if (!fileName.endsWith("Test.cls")) continue;
    const file = path.join(root, fileName);
    let source = fs.readFileSync(file, "utf8");
    const original = source;
    const replacements = [];
    for (const match of source.matchAll(constructor)) {
      const openIndex = match.index + match[0].lastIndexOf("(");
      const closeIndex = scanUntilClose(source, openIndex);
      replacements.push({
        start: match.index,
        end: closeIndex + 1,
        value: convertBody(
          match[1],
          source.slice(openIndex + 1, closeIndex),
          fileName
        )
      });
    }
    for (const replacement of replacements.reverse()) {
      source =
        source.slice(0, replacement.start) +
        replacement.value +
        source.slice(replacement.end);
    }
    source = source
      .replaceAll("System.assertNotEquals", "Assert.areNotEqual")
      .replaceAll("System.assertEquals", "Assert.areEqual")
      .replaceAll("System.assert", "Assert.isTrue");
    if (source !== original) fs.writeFileSync(file, source);
  }
}
