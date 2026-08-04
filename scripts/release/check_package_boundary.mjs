#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../.."
);
const coreDirectory = path.join(root, "force-app/main/default/customMetadata");
const fixtureDirectory = path.join(
  root,
  "integration-tests/main/default/customMetadata"
);
const examplePattern =
  /^Record_Health_Check_(?:Set|Rule)__mdt\.Example_.+\.md-meta\.xml$/;

const expectedCoreExamples = [
  "Record_Health_Check_Set__mdt.Example_Account_Profile_Readiness.md-meta.xml",
  "Record_Health_Check_Set__mdt.Example_Account_Relationship_Risk.md-meta.xml",
  "Record_Health_Check_Set__mdt.Example_Contact_Relationship_Readiness.md-meta.xml",
  "Record_Health_Check_Set__mdt.Example_Opportunity_Deal_Readiness.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Profile_Phone_Available.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Profile_Website_Available.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Profile_Industry_Classified.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Profile_Billing_Address.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Contact_RR_Email.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Contact_RR_Phone.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Contact_RR_Title.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Contact_RR_Mailing_City.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Opportunity_DR_Amount.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Opportunity_DR_Close_Date.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Opportunity_DR_Next_Step.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Opportunity_DR_Probability.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Executive_Sponsorship.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Account_Owner_Active.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Industry_Aligns_With_Parent.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Open_Deals_Have_Contacts.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Contacts_Have_Email.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Customer_Engagement_Current.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Pipeline_Protects_Revenue.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_No_High_Priority_Issues.md-meta.xml",
  "Record_Health_Check_Rule__mdt.Example_Channel_Partner_Governance.md-meta.xml"
].sort();

const expectedCardTitles = {
  "Record_Health_Check_Set__mdt.Example_Account_Profile_Readiness.md-meta.xml":
    "Demo: Account Profile Readiness",
  "Record_Health_Check_Set__mdt.Example_Account_Relationship_Risk.md-meta.xml":
    "Demo: Account Relationship & Risk Health Check",
  "Record_Health_Check_Set__mdt.Example_Contact_Relationship_Readiness.md-meta.xml":
    "Demo: Contact Relationship Readiness",
  "Record_Health_Check_Set__mdt.Example_Opportunity_Deal_Readiness.md-meta.xml":
    "Demo: Opportunity Deal Readiness"
};

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

const coreRecords = files(coreDirectory).sort();
const fixtureExamples = files(fixtureDirectory)
  .filter((name) => examplePattern.test(name))
  .sort();
const failures = [];

if (JSON.stringify(coreRecords) !== JSON.stringify(expectedCoreExamples)) {
  failures.push(
    `force-app Custom Metadata must be exactly the 25 Demo Example_ records.\n` +
      `  expected: ${expectedCoreExamples.join(", ")}\n` +
      `  found:    ${coreRecords.join(", ") || "(none)"}`
  );
}

if (JSON.stringify(fixtureExamples) !== JSON.stringify(expectedCoreExamples)) {
  failures.push(
    `integration-tests must retain matching copies of the 25 Demo Example_ records.\n` +
      `  expected: ${expectedCoreExamples.join(", ")}\n` +
      `  found:    ${fixtureExamples.join(", ") || "(none)"}`
  );
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
  `Verified package boundary: ${coreRecords.length} Demo Example_ records in force-app ` +
    `with matching integration-tests fixtures and Demo: card titles.`
);
