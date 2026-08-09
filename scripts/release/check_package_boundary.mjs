#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { paths } from "../lib/paths.mjs";

const root = paths.repoRoot;
const coreDirectory = path.join(paths.forceApp, "main/default/customMetadata");
const fixtureDirectory = path.join(
  paths.integrationTests,
  "main/default/customMetadata"
);
const examplePattern =
  /^(?:Record_Health_Check_Set__mdt|Record_Health_Check__mdt)\.Example_.+\.md-meta\.xml$/;

const expectedCoreExamples = [
  "Record_Health_Check_Set__mdt.Example_Account_Profile_Readiness.md-meta.xml",
  "Record_Health_Check_Set__mdt.Example_Account_Relationship_Risk.md-meta.xml",
  "Record_Health_Check_Set__mdt.Example_Contact_Relationship_Readiness.md-meta.xml",
  "Record_Health_Check_Set__mdt.Example_Opportunity_Deal_Readiness.md-meta.xml",
  "Record_Health_Check__mdt.Example_Profile_Phone_Available.md-meta.xml",
  "Record_Health_Check__mdt.Example_Profile_Website_Available.md-meta.xml",
  "Record_Health_Check__mdt.Example_Profile_Industry_Classified.md-meta.xml",
  "Record_Health_Check__mdt.Example_Profile_Billing_Address.md-meta.xml",
  "Record_Health_Check__mdt.Example_Contact_RR_Email.md-meta.xml",
  "Record_Health_Check__mdt.Example_Contact_RR_Phone.md-meta.xml",
  "Record_Health_Check__mdt.Example_Contact_RR_Title.md-meta.xml",
  "Record_Health_Check__mdt.Example_Contact_RR_Mailing_City.md-meta.xml",
  "Record_Health_Check__mdt.Example_Opportunity_DR_Amount.md-meta.xml",
  "Record_Health_Check__mdt.Example_Opportunity_DR_Close_Date.md-meta.xml",
  "Record_Health_Check__mdt.Example_Opportunity_DR_Next_Step.md-meta.xml",
  "Record_Health_Check__mdt.Example_Opportunity_DR_Probability.md-meta.xml",
  "Record_Health_Check__mdt.Example_Executive_Sponsorship.md-meta.xml",
  "Record_Health_Check__mdt.Example_Account_Owner_Active.md-meta.xml",
  "Record_Health_Check__mdt.Example_Industry_Aligns_With_Parent.md-meta.xml",
  "Record_Health_Check__mdt.Example_Open_Deals_Have_Contacts.md-meta.xml",
  "Record_Health_Check__mdt.Example_Contacts_Have_Email.md-meta.xml",
  "Record_Health_Check__mdt.Example_Customer_Engagement_Current.md-meta.xml",
  "Record_Health_Check__mdt.Example_Pipeline_Protects_Revenue.md-meta.xml",
  "Record_Health_Check__mdt.Example_No_High_Priority_Issues.md-meta.xml",
  "Record_Health_Check__mdt.Example_Channel_Partner_Governance.md-meta.xml"
].sort();

const expectedCardTitles = {
  "Record_Health_Check_Set__mdt.Example_Account_Profile_Readiness.md-meta.xml":
    "Example: Account Profile Readiness",
  "Record_Health_Check_Set__mdt.Example_Account_Relationship_Risk.md-meta.xml":
    "Example: Account Relationship & Risk Health Check",
  "Record_Health_Check_Set__mdt.Example_Contact_Relationship_Readiness.md-meta.xml":
    "Example: Contact Relationship Readiness",
  "Record_Health_Check_Set__mdt.Example_Opportunity_Deal_Readiness.md-meta.xml":
    "Example: Opportunity Deal Readiness"
};

const overLimitExampleSet =
  "Record_Health_Check_Set__mdt.Example_Account_Over_25_Checks.md-meta.xml";
const overLimitExampleChecks = Array.from(
  { length: 30 },
  (_, index) =>
    `Record_Health_Check__mdt.Example_Over_25_Limit_${String(index + 1).padStart(2, "0")}.md-meta.xml`
);

const files = (directory) =>
  fs.existsSync(directory)
    ? fs.readdirSync(directory).filter((name) => name.endsWith(".md-meta.xml"))
    : [];

const decodeXml = (value) =>
  value
    .replaceAll("&amp;", "&")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">")
    .replaceAll("&quot;", '"')
    .replaceAll("&apos;", "'");

const cardTitle = (directory, fileName) => {
  const text = fs.readFileSync(path.join(directory, fileName), "utf8");
  const match = text.match(
    /<field>CardTitle__c<\/field>\s*<value[^>]*>([\s\S]*?)<\/value>/
  );
  return match ? decodeXml(match[1].trim()) : null;
};

const checkSetIdentity = (directory, fileName) => {
  const text = fs.readFileSync(path.join(directory, fileName), "utf8");
  const match = text.match(
    /<field>Record_Health_Check_Set__c<\/field>\s*<value[^>]*>([\s\S]*?)<\/value>/
  );
  return match ? decodeXml(match[1].trim()) : null;
};

const coreRecords = files(coreDirectory).sort();
const fixtureExamples = files(fixtureDirectory)
  .filter((name) => examplePattern.test(name))
  .sort();
const fixtureCoreExamples = fixtureExamples.filter((name) =>
  expectedCoreExamples.includes(name)
);
const failures = [];

for (const directory of [coreDirectory, fixtureDirectory]) {
  for (const fileName of files(directory)) {
    const identity = fileName.replace(
      /^(?:Record_Health_Check_Set__mdt|Record_Health_Check__mdt)\.|\.md-meta\.xml$/g,
      ""
    );
    if (identity.length > 40) {
      failures.push(
        `${path.relative(root, path.join(directory, fileName))} Custom Metadata ` +
          `Developer Name is ${identity.length} characters; Salesforce allows 40`
      );
    }
  }
}

if (JSON.stringify(coreRecords) !== JSON.stringify(expectedCoreExamples)) {
  failures.push(
    `force-app Custom Metadata must be exactly the 25 shipped Example_ records.\n` +
      `  expected: ${expectedCoreExamples.join(", ")}\n` +
      `  found:    ${coreRecords.join(", ") || "(none)"}`
  );
}

if (
  JSON.stringify(fixtureCoreExamples) !== JSON.stringify(expectedCoreExamples)
) {
  failures.push(
    `integration-tests must retain matching copies of the 25 shipped Example_ records.\n` +
      `  expected: ${expectedCoreExamples.join(", ")}\n` +
      `  found:    ${fixtureCoreExamples.join(", ") || "(none)"}`
  );
}

const missingOverLimitRecords = [
  overLimitExampleSet,
  ...overLimitExampleChecks
].filter((fileName) => !fs.existsSync(path.join(fixtureDirectory, fileName)));
if (missingOverLimitRecords.length > 0) {
  failures.push(
    `integration-tests must include the complete 30-Check LWC ceiling example. Missing: ` +
      missingOverLimitRecords.join(", ")
  );
}

for (const fileName of fixtureExamples.filter((name) =>
  name.startsWith("Record_Health_Check_Set__mdt.")
)) {
  const actual = cardTitle(fixtureDirectory, fileName);
  if (!actual?.startsWith("Example:")) {
    failures.push(
      `${path.relative(root, path.join(fixtureDirectory, fileName))} CardTitle__c ` +
        `must start with "Example:" (found "${actual}")`
    );
  }
}

for (const fileName of files(fixtureDirectory).filter((name) =>
  name.startsWith("Record_Health_Check__mdt.")
)) {
  const parent = checkSetIdentity(fixtureDirectory, fileName);
  const checkIdentity = fileName.replace(
    /^Record_Health_Check__mdt\.|\.md-meta\.xml$/g,
    ""
  );
  if (parent?.startsWith("Example_") && !checkIdentity.startsWith("Example_")) {
    failures.push(
      `${path.relative(root, path.join(fixtureDirectory, fileName))} belongs to ` +
        `${parent} and must use an Example_ API name`
    );
  }
}

for (const [fileName, expectedTitle] of Object.entries(expectedCardTitles)) {
  for (const directory of [coreDirectory, fixtureDirectory]) {
    if (!fs.existsSync(path.join(directory, fileName))) {
      continue;
    }
    const actual = cardTitle(directory, fileName);
    if (actual !== expectedTitle) {
      failures.push(
        `${path.relative(root, path.join(directory, fileName))} CardTitle__c ` +
          `must be "${expectedTitle}" (found "${actual}")`
      );
    }
  }
}

for (const fileName of expectedCoreExamples) {
  const corePath = path.join(coreDirectory, fileName);
  const fixturePath = path.join(fixtureDirectory, fileName);
  if (!fs.existsSync(corePath) || !fs.existsSync(fixturePath)) {
    continue;
  }
  const coreText = fs.readFileSync(corePath, "utf8");
  const fixtureText = fs.readFileSync(fixturePath, "utf8");
  if (coreText !== fixtureText) {
    failures.push(
      `${fileName} must be identical in force-app and integration-tests`
    );
  }
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(
  `Verified package boundary: ${coreRecords.length} shipped Example_ records in force-app ` +
    `with matching integration-tests fixtures, the 30-Check LWC ceiling example, and Example: card titles.`
);
