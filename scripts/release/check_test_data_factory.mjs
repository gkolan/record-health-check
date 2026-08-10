import fs from "node:fs";
import path from "node:path";
import { paths } from "../lib/paths.mjs";

const classDirectories = [
  path.join(paths.forceApp, "main/default/classes"),
  path.join(paths.integrationTests, "main/default/classes")
];
const factoryFile = "RecordHealthCheckTestDataFactory.cls";
const directDmlPattern =
  /\b(?:insert|upsert)\s+|\bDatabase\.(?:insert|upsert)\s*\(/g;
const inlineRecordPattern =
  /\bnew\s+(?:Account|Case|Contact|Event|Group|Opportunity|Task|User|Record_Health_Check_[A-Za-z0-9_]*__mdt|RHC_[A-Za-z0-9_]*__(?:c|e))\s*\(/g;
const hardcodedNamespacePattern = /['"]rhc__/g;
const failures = [];

function codeOnly(source) {
  return source
    .replace(/'(?:\\.|[^'])*'/gs, (value) => value.replace(/[^\n]/g, " "))
    .replace(/\/\*[\s\S]*?\*\//g, (value) => value.replace(/[^\n]/g, " "))
    .replace(/\/\/[^\n]*/g, (value) => " ".repeat(value.length));
}

for (const classesDirectory of classDirectories) {
  for (const fileName of fs.readdirSync(classesDirectory).sort()) {
    if (!fileName.endsWith("Test.cls") || fileName.includes("TestDataFactory"))
      continue;

    const source = fs.readFileSync(
      path.join(classesDirectory, fileName),
      "utf8"
    );
    const scannedSource = codeOnly(source);
    for (const match of scannedSource.matchAll(directDmlPattern)) {
      const line = source.slice(0, match.index).split("\n").length;
      failures.push(
        `${fileName}:${line}: create persisted test records through ${factoryFile}`
      );
    }
    for (const match of scannedSource.matchAll(inlineRecordPattern)) {
      const line = source.slice(0, match.index).split("\n").length;
      failures.push(
        `${fileName}:${line}: construct Salesforce records through a TestDataFactory`
      );
    }
  }
}

const forceAppClasses = path.join(paths.forceApp, "main/default/classes");
for (const fileName of fs.readdirSync(forceAppClasses).sort()) {
  if (!fileName.endsWith(".cls")) continue;
  const source = fs.readFileSync(path.join(forceAppClasses, fileName), "utf8");
  const scannedSource = codeOnly(source);
  for (const match of scannedSource.matchAll(hardcodedNamespacePattern)) {
    const line = source.slice(0, match.index).split("\n").length;
    failures.push(
      `${fileName}:${line}: avoid hardcoded rhc__ literals; use schema tokens or queried QualifiedApiName`
    );
  }
}

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  "Verified Apex tests: Salesforce record construction and persisted creation are centralized in TestDataFactory classes."
);
