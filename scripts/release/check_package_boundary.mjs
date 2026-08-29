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
  /^(?:Record_Health_Check_Set|Record_Health_Check)\.Example_.+\.md-meta\.xml$/;

const expectedCoreExamples = [
  "Record_Health_Check_Set.Example_Account_Check_Builder_Guide.md-meta.xml",
  "Record_Health_Check_Set.Example_Account_Relationship_Risk.md-meta.xml",
  "Record_Health_Check_Set.Example_Contact_Relationship_Readiness.md-meta.xml",
  "Record_Health_Check_Set.Example_Opportunity_Deal_Readiness.md-meta.xml",
  "Record_Health_Check.Example_Website_URL_Valid.md-meta.xml",
  "Record_Health_Check.Example_Contact_RR_Account.md-meta.xml",
  "Record_Health_Check.Example_Contact_RR_Email.md-meta.xml",
  "Record_Health_Check.Example_Contact_RR_Owner_Active.md-meta.xml",
  "Record_Health_Check.Example_Contact_RR_Phone.md-meta.xml",
  "Record_Health_Check.Example_Contact_RR_Reachable_Channel.md-meta.xml",
  "Record_Health_Check.Example_Contact_RR_Recent_Engagement.md-meta.xml",
  "Record_Health_Check.Example_Contact_RR_Title.md-meta.xml",
  "Record_Health_Check.Example_Contact_RR_Mailing_City.md-meta.xml",
  "Record_Health_Check.Example_Opportunity_DR_Account.md-meta.xml",
  "Record_Health_Check.Example_Opportunity_DR_Amount.md-meta.xml",
  "Record_Health_Check.Example_Opportunity_DR_Buyer_Contact.md-meta.xml",
  "Record_Health_Check.Example_Opportunity_DR_Close_Date.md-meta.xml",
  "Record_Health_Check.Example_Opportunity_DR_Next_Step.md-meta.xml",
  "Record_Health_Check.Example_Opportunity_DR_Owner_Active.md-meta.xml",
  "Record_Health_Check.Example_Opportunity_DR_Probability.md-meta.xml",
  "Record_Health_Check.Example_Opportunity_DR_Recent_Activity.md-meta.xml",
  "Record_Health_Check.Example_Executive_Sponsorship.md-meta.xml",
  "Record_Health_Check.Example_Guide_Contacts_Have_Email.md-meta.xml",
  "Record_Health_Check.Example_Guide_Recent_Activity.md-meta.xml",
  "Record_Health_Check.Example_Guide_Industry_Manufacturing.md-meta.xml",
  "Record_Health_Check.Example_Guide_Open_Deals_Have_Contacts.md-meta.xml",
  "Record_Health_Check.Example_Account_Owner_Active.md-meta.xml",
  "Record_Health_Check.Example_Open_Cases_Have_Contacts.md-meta.xml",
  "Record_Health_Check.Example_Industry_Aligns_With_Parent.md-meta.xml",
  "Record_Health_Check.Example_Open_Deals_Have_Contacts.md-meta.xml",
  "Record_Health_Check.Example_Contacts_Have_Email.md-meta.xml",
  "Record_Health_Check.Example_Customer_Engagement_Current.md-meta.xml",
  "Record_Health_Check.Example_Pipeline_Protects_Revenue.md-meta.xml",
  "Record_Health_Check.Example_No_High_Priority_Issues.md-meta.xml",
  "Record_Health_Check.Example_Channel_Partner_Governance.md-meta.xml",
  "Record_Health_Check.Example_Segregation_Of_Duties.md-meta.xml",
  "Record_Health_Check.Example_Has_At_Least_One_Contact.md-meta.xml",
  "Record_Health_Check.Example_Fewer_Than_Ten_Open_Cases.md-meta.xml",
  "Record_Health_Check.Example_Open_Opps_Have_Amount.md-meta.xml",
  "Record_Health_Check.Example_High_Value_Open_Opp.md-meta.xml",
  "Record_Health_Check.Example_Significant_Open_Opp.md-meta.xml",
  "Record_Health_Check.Example_Contact_States_Match_Billing.md-meta.xml",
  "Record_Health_Check.Example_Billing_State_In_Contacts.md-meta.xml",
  "Record_Health_Check.Example_Contacts_Cover_Open_Cases.md-meta.xml",
  "Record_Health_Check.Example_Contact_Vs_Open_Opp_Count.md-meta.xml",
  "Record_Health_Check.Example_Oldest_Contact_City_Matches.md-meta.xml",
  "Record_Health_Check.Example_Open_Pipeline_Covers_Revenue.md-meta.xml",
  "Record_Health_Check.Example_Average_Deal_Vs_Largest.md-meta.xml",
  "Record_Health_Check.Example_Earliest_Vs_Latest_Close.md-meta.xml",
  "Record_Health_Check.Example_Distinct_Cities_Vs_Contacts.md-meta.xml",
  "Record_Health_Check.Example_Contact_Cities_Overlap_Parent.md-meta.xml",
  "Record_Health_Check.Example_Parent_Covers_Contact_Cities.md-meta.xml",
  "Record_Health_Check.Example_Contact_Cities_Exact_Parent.md-meta.xml",
  "Record_Health_Check.Example_Parent_Cities_Require_Data.md-meta.xml"
].sort();

const expectedCardTitles = {
  "Record_Health_Check_Set.Example_Account_Check_Builder_Guide.md-meta.xml":
    "Example: Account Check Builder Guide",
  "Record_Health_Check_Set.Example_Account_Relationship_Risk.md-meta.xml":
    "Example: Account Relationship & Risk Health Check",
  "Record_Health_Check_Set.Example_Contact_Relationship_Readiness.md-meta.xml":
    "Example: Contact Relationship Readiness",
  "Record_Health_Check_Set.Example_Opportunity_Deal_Readiness.md-meta.xml":
    "Example: Opportunity Deal Readiness"
};

const overLimitExampleSet =
  "Record_Health_Check_Set.Example_Account_Over_25_Checks.md-meta.xml";
const overLimitExampleChecks = Array.from(
  { length: 30 },
  (_, index) =>
    `Record_Health_Check.Example_Over_25_Limit_${String(index + 1).padStart(2, "0")}.md-meta.xml`
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

const customMetadataValues = (directory, fileName) => {
  const text = fs.readFileSync(path.join(directory, fileName), "utf8");
  const values = new Map();
  for (const block of text.matchAll(/<values>([\s\S]*?)<\/values>/g)) {
    const field = block[1].match(/<field>([^<]+)<\/field>/)?.[1]?.trim();
    const value = block[1].match(/<value[^>]*>([\s\S]*?)<\/value>/)?.[1];
    if (field) values.set(field, value == null ? "" : decodeXml(value.trim()));
  }
  return values;
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
      /^(?:Record_Health_Check_Set|Record_Health_Check)\.|\.md-meta\.xml$/g,
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
    `force-app Custom Metadata must match the shipped Example_ record inventory.\n` +
      `  expected: ${expectedCoreExamples.join(", ")}\n` +
      `  found:    ${coreRecords.join(", ") || "(none)"}`
  );
}

if (
  JSON.stringify(fixtureCoreExamples) !== JSON.stringify(expectedCoreExamples)
) {
  failures.push(
    `integration-tests must retain matching copies of the 54 shipped Example_ records.\n` +
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
  name.startsWith("Record_Health_Check_Set.")
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
  name.startsWith("Record_Health_Check.")
)) {
  const parent = checkSetIdentity(fixtureDirectory, fileName);
  const checkIdentity = fileName.replace(
    /^Record_Health_Check\.|\.md-meta\.xml$/g,
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

const accountGuideSet = "Example_Account_Check_Builder_Guide";
const activeAccountGuideChecks = coreRecords
  .filter((fileName) => fileName.startsWith("Record_Health_Check.Example_"))
  .map((fileName) => ({
    fileName,
    values: customMetadataValues(coreDirectory, fileName)
  }))
  .filter(
    ({ values }) =>
      values.get("Record_Health_Check_Set__c") === accountGuideSet &&
      values.get("IsActive__c") === "true"
  );

if (activeAccountGuideChecks.length !== 25) {
  failures.push(
    `${accountGuideSet} must contain exactly 25 active Checks; found ${activeAccountGuideChecks.length}`
  );
}

const expectedEvaluationTypeCounts = new Map([
  ["FORMULA", 3],
  ["QUERY", 10],
  ["COMPARE_TWO_QUERIES", 11],
  ["APEX", 1]
]);
for (const [evaluationType, expectedCount] of expectedEvaluationTypeCounts) {
  const actualCount = activeAccountGuideChecks.filter(
    ({ values }) => values.get("EvaluationType__c") === evaluationType
  ).length;
  if (actualCount !== expectedCount) {
    failures.push(
      `${accountGuideSet} must contain ${expectedCount} ${evaluationType} Checks; found ${actualCount}`
    );
  }
}

for (const severity of ["CRITICAL", "WARNING", "INFO"]) {
  if (
    !activeAccountGuideChecks.some(
      ({ values }) => values.get("FailureSeverity__c") === severity
    )
  ) {
    failures.push(
      `${accountGuideSet} must demonstrate the ${severity} failure severity`
    );
  }
}

const requiredTeachingFields = [
  "Record_Health_Check_Set__c",
  "EvaluationOrder__c",
  "IsActive__c",
  "CheckTitle__c",
  "CheckDescription__c",
  "FailureSeverity__c",
  "FailureMessage__c",
  "UnableToEvaluateMessage__c",
  "FixMessage__c",
  "ActionLabel__c",
  "ActionUrl__c",
  "PublishUserResultEvent__c",
  "ApplicabilityMode__c",
  "DisplayValueFormat__c"
];
const mergeTeachingFields = [
  "FailureMessage__c",
  "UnableToEvaluateMessage__c",
  "FixMessage__c",
  "ActionLabel__c",
  "ActionUrl__c"
];
const mergeQueryFields = [
  "SourceQuery__c",
  "ComparisonQuery__c",
  "ApplicabilityCountQuery__c"
];
for (const { fileName, values } of activeAccountGuideChecks) {
  for (const field of requiredTeachingFields) {
    if (!values.get(field)) {
      failures.push(`${fileName} must populate ${field} for the Account guide`);
    }
  }
  if ((values.get("CheckDescription__c") ?? "").length > 255) {
    failures.push(`${fileName} CheckDescription__c exceeds 255 characters`);
  }
  const metadataText = fs.readFileSync(
    path.join(coreDirectory, fileName),
    "utf8"
  );
  if (
    !/<field>Category__c<\/field>\s*<value xsi:nil="true"\s*\/>/.test(
      metadataText
    )
  ) {
    failures.push(
      `${fileName} must explicitly clear Category__c in the Account guide`
    );
  }
  const evaluationTypeLabel = new Map([
    ["FORMULA", "formula"],
    ["QUERY", "Query check"],
    ["COMPARE_TWO_QUERIES", "Compare Two Queries"],
    ["APEX", "Apex"]
  ]).get(values.get("EvaluationType__c"));
  const description = values.get("CheckDescription__c") ?? "";
  if (
    !evaluationTypeLabel ||
    !description.toLowerCase().includes(evaluationTypeLabel.toLowerCase())
  ) {
    failures.push(
      `${fileName} CheckDescription__c must name its evaluation type`
    );
  }
  if (!/passes(?: only)? when/.test(description)) {
    failures.push(
      `${fileName} CheckDescription__c must explain the passing comparison`
    );
  }
  for (const field of mergeTeachingFields) {
    if (!values.get(field)?.includes("{!")) {
      failures.push(`${fileName} ${field} must demonstrate merge syntax`);
    }
  }
  for (const field of mergeQueryFields) {
    const query = values.get(field);
    if (query && !query.includes("{!record.")) {
      failures.push(
        `${fileName} ${field} must use a current-record merge value`
      );
    }
  }
  if (values.get("EvaluationType__c") === "FORMULA") {
    for (const field of [
      "DisplayFoundFormula__c",
      "DisplayExpectedFormula__c"
    ]) {
      if (!values.get(field)) {
        failures.push(`${fileName} must populate ${field}`);
      }
    }
  } else if (values.get("EvaluationType__c") !== "APEX") {
    for (const field of ["DisplayFoundText__c", "DisplayExpectedText__c"]) {
      if (!values.get(field)?.includes("{!")) {
        failures.push(`${fileName} ${field} must demonstrate merge syntax`);
      }
      if (/^(Found|Expected)\s*:/i.test(values.get(field) ?? "")) {
        failures.push(
          `${fileName} ${field} must not repeat the card's Found or Expected label`
        );
      }
    }
  }
  if (
    values.get("ApplicabilityMode__c") !== "ALL_RECORDS" &&
    !values.get("ApplicabilityNotMetMessage__c")?.includes("{!")
  ) {
    failures.push(
      `${fileName} ApplicabilityNotMetMessage__c must demonstrate merge syntax`
    );
  }
}

const checkFieldDirectory = path.join(
  paths.forceApp,
  "main/default/objects/Record_Health_Check__mdt/fields"
);
const checkFieldNames = fs
  .readdirSync(checkFieldDirectory)
  .filter((name) => name.endsWith(".field-meta.xml"))
  .map((name) => name.replace(".field-meta.xml", ""));
const demonstratedFields = new Set(
  activeAccountGuideChecks.flatMap(({ values }) => [...values.keys()])
);
for (const fieldName of checkFieldNames) {
  if (fieldName === "Category__c") {
    continue;
  }
  if (!demonstratedFields.has(fieldName)) {
    failures.push(
      `${accountGuideSet} does not demonstrate the ${fieldName} Check field`
    );
  }
}

const accountGuideSetFile =
  "Record_Health_Check_Set.Example_Account_Check_Builder_Guide.md-meta.xml";
const accountGuideSetValues = customMetadataValues(
  coreDirectory,
  accountGuideSetFile
);
const checkSetFieldDirectory = path.join(
  paths.forceApp,
  "main/default/objects/Record_Health_Check_Set__mdt/fields"
);
for (const fieldName of fs
  .readdirSync(checkSetFieldDirectory)
  .filter((name) => name.endsWith(".field-meta.xml"))
  .map((name) => name.replace(".field-meta.xml", ""))) {
  if (!accountGuideSetValues.has(fieldName)) {
    failures.push(`${accountGuideSetFile} must populate ${fieldName}`);
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
