import fs from "node:fs";
import path from "node:path";
import { paths } from "../lib/paths.mjs";

const classesDir = path.join(paths.forceApp, "main/default/classes");
const outputPath = path.join(
  paths.repoRoot,
  "scripts/release/generated/test-data-factory-inventory.json"
);
const persistMethods = new Set([
  "createAccount",
  "createAccounts",
  "createContact",
  "createContacts",
  "createOpportunity",
  "createOpportunities",
  "createTask",
  "createEvent",
  "createTestRecords",
  "createCoverageTestRecords",
  "createCompletedTask",
  "createDeletedAccount",
  "createEmailCoverageContacts",
  "createMatchingCityContacts"
]);
const userMethods = new Set([
  "createUser",
  "createUserWithLocale",
  "createMinimumAccessUser",
  "createInactiveUser"
]);

const classes = [];
for (const file of fs.readdirSync(classesDir).sort()) {
  if (!file.endsWith("Test.cls")) continue;
  const source = fs.readFileSync(path.join(classesDir, file), "utf8");
  const calls = [
    ...source.matchAll(
      /RecordHealthCheck(?:Persona)?TestDataFactory\.([A-Za-z0-9_]+)\s*\(/g
    )
  ].map((match) => ({
    method: match[1],
    line: source.slice(0, match.index).split("\n").length
  }));
  if (!calls.length) continue;
  const persisted = calls.filter((call) => persistMethods.has(call.method));
  const users = calls.filter((call) => userMethods.has(call.method));
  classes.push({
    className: file.replace(/\.cls$/, ""),
    classification: persisted.length
      ? users.length
        ? "Hybrid"
        : "B"
      : users.length
        ? "C"
        : "safe",
    targetSteps: persisted.length ? [15, 16, 17, 18] : users.length ? [4] : [],
    hasTestSetup: /@TestSetup\b/.test(source),
    persistedCalls: persisted,
    userCalls: users
  });
}

const inventory = {
  schemaVersion: 1,
  generatedFrom:
    "packages/record-health-check/force-app/main/default/classes/*Test.cls",
  summary: {
    classes: classes.length,
    persistedCallSites: classes.reduce(
      (sum, item) => sum + item.persistedCalls.length,
      0
    ),
    userCallSites: classes.reduce(
      (sum, item) => sum + item.userCalls.length,
      0
    ),
    safeClasses: classes.filter((item) => item.classification === "safe").length
  },
  classes
};
const rendered = `${JSON.stringify(inventory, null, 2)}\n`;

if (process.argv.includes("--check")) {
  const current = fs.existsSync(outputPath)
    ? fs.readFileSync(outputPath, "utf8")
    : "";
  if (current !== rendered) {
    console.error(
      "Test-data factory inventory is stale. Regenerate it with npm run generate:test-data-factory-inventory."
    );
    process.exit(1);
  }
  console.log("Test-data factory inventory matches force-app test call sites.");
} else {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, rendered);
  console.log(`Wrote ${path.relative(paths.repoRoot, outputPath)}.`);
}
