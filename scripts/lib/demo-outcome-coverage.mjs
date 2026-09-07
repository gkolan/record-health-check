import fs from "node:fs";
import path from "node:path";

function metadataValues(xml) {
  const values = new Map();
  for (const block of xml.matchAll(/<values>([\s\S]*?)<\/values>/g)) {
    const field = block[1].match(/<field>([^<]+)<\/field>/)?.[1];
    const rawValue = block[1].match(/<value[^>]*>([\s\S]*?)<\/value>/)?.[1];
    if (field && rawValue !== undefined)
      values.set(field, rawValue.replace(/<[^>]+>/g, "").trim());
  }
  return values;
}

/** Return gaps between packaged example Checks and executable demo outcomes. */
export function demoOutcomeCoverageGaps(metadataDirectory, matrix) {
  const allowedStatuses = new Set([
    "PASS",
    "FAIL",
    "SKIPPED",
    "UNABLE_TO_EVALUATE",
    "SYSTEM_ERROR"
  ]);
  const checksBySet = new Map();
  const requirementsByCheck = new Map();
  for (const fileName of fs
    .readdirSync(metadataDirectory)
    .filter((name) => name.startsWith("Record_Health_Check.Example_"))) {
    const developerName = fileName
      .replace("Record_Health_Check.", "")
      .replace(".md-meta.xml", "");
    const values = metadataValues(
      fs.readFileSync(path.join(metadataDirectory, fileName), "utf8")
    );
    if (values.get("IsActive__c") !== "true") continue;
    const checkSet = values.get("Record_Health_Check_Set__c");
    if (!checksBySet.has(checkSet)) checksBySet.set(checkSet, new Set());
    checksBySet.get(checkSet).add(developerName);
    const required = new Set(["PASS", "FAIL"]);
    if (
      values.get("ApplicabilityMode__c") !== "ALL_RECORDS" ||
      values.get("NoRowsResult__c") === "SKIP"
    )
      required.add("SKIPPED");
    if (values.get("NoRowsResult__c") === "UNABLE_TO_EVALUATE")
      required.add("UNABLE_TO_EVALUATE");
    requirementsByCheck.set(developerName, required);
  }

  const outcomesByCheck = new Map();
  const scenarioSets = new Set();
  const gaps = [];
  for (const [scenarioName, scenario] of Object.entries(matrix)) {
    scenarioSets.add(scenario.checkSet);
    const packagedChecks = checksBySet.get(scenario.checkSet);
    if (!packagedChecks) {
      gaps.push(`${scenarioName} names an unknown packaged Check Set.`);
      continue;
    }
    let hasHealthyRecord = false;
    let hasNeedsReviewRecord = false;
    for (const [recordName, outcomes] of Object.entries(scenario.records)) {
      const statuses = Object.values(outcomes);
      hasHealthyRecord ||=
        statuses.includes("PASS") &&
        statuses.every((status) => status === "PASS" || status === "SKIPPED");
      hasNeedsReviewRecord ||= statuses.includes("FAIL");
      const actualChecks = new Set(Object.keys(outcomes));
      const missing = [...packagedChecks].filter(
        (check) => !actualChecks.has(check)
      );
      const extra = [...actualChecks].filter(
        (check) => !packagedChecks.has(check)
      );
      if (missing.length)
        gaps.push(
          `${scenarioName} / ${recordName} omits: ${missing.join(", ")}`
        );
      if (extra.length)
        gaps.push(
          `${scenarioName} / ${recordName} includes unknown or inactive Checks: ${extra.join(", ")}`
        );
      for (const [check, status] of Object.entries(outcomes)) {
        if (!allowedStatuses.has(status))
          gaps.push(
            `${scenarioName} / ${recordName} / ${check} has unknown status ${status}.`
          );
        if (!outcomesByCheck.has(check)) outcomesByCheck.set(check, new Set());
        outcomesByCheck.get(check).add(status);
      }
    }
    if (!hasHealthyRecord)
      gaps.push(`${scenarioName} has no record with zero failed Checks.`);
    if (!hasNeedsReviewRecord)
      gaps.push(`${scenarioName} has no record with a failed Check.`);
  }

  for (const checkSet of checksBySet.keys()) {
    if (!scenarioSets.has(checkSet))
      gaps.push(`${checkSet} has no executable demo scenario.`);
  }
  for (const [check, required] of requirementsByCheck) {
    const actual = outcomesByCheck.get(check) ?? new Set();
    const missing = [...required].filter((status) => !actual.has(status));
    if (missing.length)
      gaps.push(`${check} has no expected ${missing.join(" or ")} outcome.`);
  }
  return gaps;
}
