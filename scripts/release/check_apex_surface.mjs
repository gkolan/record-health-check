import fs from "node:fs";
import path from "node:path";

const classRoot = "packages/record-health-check/force-app/main/default/classes";
// Measured no-growth ceilings. Existing hotspots are recorded in the Step 10
// review; reductions must lower these values in the same change.
const maxMethodLines = 416;
const maxDecisionPoints = 51;
const approvedProductionRhcNames = new Set([
  "RHCConstructorMutationCheck",
  "RHCMetadataDependencyValidator"
]);
const failures = [];
let globalMembers = 0;
let methods = 0;

for (const file of fs
  .readdirSync(classRoot)
  .filter((name) => name.endsWith(".cls"))) {
  if (file.includes("Test")) continue;
  const relative = path.join(classRoot, file);
  const source = fs.readFileSync(relative, "utf8");
  const lines = source.split(/\r?\n/);

  for (let index = 0; index < lines.length; index++) {
    if (!/^\s*global\s/.test(lines[index])) continue;
    globalMembers++;
    let previous = index - 1;
    while (previous >= 0 && !lines[previous].trim()) previous--;
    if (previous < 0 || !lines[previous].includes("*/")) {
      failures.push(
        `${relative}:${index + 1}: global declaration requires adjacent ApexDoc.`
      );
    }
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

if (failures.length) {
  console.error("Apex surface policy failed:\n- " + failures.join("\n- "));
  process.exit(1);
}
console.log(
  `Apex surface policy passed: ${globalMembers} global declarations documented; ${methods} methods checked (max ${maxMethodLines} lines / ${maxDecisionPoints} decisions).`
);
