import assert from "node:assert/strict";
import test from "node:test";
import {
  BOTH_STATES,
  coverageGaps,
  decodeXmlText,
  displayFormats,
  fieldLength,
  fixtureValues,
  lengthGaps,
  MAX_MASTER_LABEL,
  picklistValues,
  surfaceGaps,
  tokenProperties
} from "./fixture-value-coverage.mjs";

const bothStatesCovered = new Map(
  BOTH_STATES.map((field) => [field, new Set(["true", "false"])])
);

test("reads restricted picklist values out of prettier-wrapped field metadata", () => {
  const fieldXml = `<CustomField>
    <fullName>FoundExpectedDisplay__c</fullName>
    <valueSet><valueSetDefinition>
      <value><fullName>ON_DEMAND</fullName></value><value><fullName
    >FAILURES_ONLY</fullName></value><value><fullName
    >ALL_ROWS</fullName></value>
    </valueSetDefinition></valueSet>
  </CustomField>`;
  assert.deepEqual(picklistValues(fieldXml), [
    "ON_DEMAND",
    "FAILURES_ONLY",
    "ALL_ROWS"
  ]);
  assert.deepEqual(
    picklistValues("<CustomField><type>Text</type></CustomField>"),
    []
  );
});

test("reads fixture field values, including explicitly cleared fields", () => {
  const recordXml = `<CustomMetadata>
    <values><field>Category__c</field><value xsi:nil="true"/></values>
    <values><field>FormulaResultType__c</field><value
      xsi:type="xsd:string"
    >DATETIME</value></values>
    <values><field>CheckTitle__c</field><value xsi:type="xsd:string"
    >Research &amp; Development &#x26; Support</value></values>
  </CustomMetadata>`;
  assert.deepEqual(fixtureValues(recordXml), [
    ["Category__c", ""],
    ["FormulaResultType__c", "DATETIME"],
    ["CheckTitle__c", "Research & Development & Support"]
  ]);
});

test("decodes XML references before stored lengths are measured", () => {
  assert.equal(
    decodeXmlText("&lt;&gt;&quot;&apos;&amp;&#65;&#x42;"),
    `<>"'&AB`
  );
  const [pair] = fixtureValues(
    `<values><field>CardSubtitle__c</field><value>${"x".repeat(
      254
    )}&amp;</value></values>`
  );
  assert.equal(pair[1].length, 255);
});

test("reports every picklist value no fixture exercises", () => {
  const declared = new Map([
    ["Record_Health_Check__mdt.Category__c", ["COMPLETENESS", "RISK"]]
  ]);
  const used = new Map([
    ...bothStatesCovered,
    ["Record_Health_Check__mdt.Category__c", new Set(["COMPLETENESS"])]
  ]);
  assert.deepEqual(coverageGaps(declared, used), [
    "Record_Health_Check__mdt.Category__c has no integration-test fixture for: RISK"
  ]);
});

test("reports a behavioral checkbox that only ever appears in one state", () => {
  const used = new Map([
    ...bothStatesCovered,
    ["Record_Health_Check_Set__mdt.StopOnSystemError__c", new Set(["false"])]
  ]);
  assert.deepEqual(coverageGaps(new Map(), used), [
    "Record_Health_Check_Set__mdt.StopOnSystemError__c has no integration-test fixture for: true"
  ]);
});

test("stays silent when every declared value is exercised", () => {
  const declared = new Map([
    ["Record_Health_Check__mdt.Category__c", ["COMPLETENESS"]]
  ]);
  const used = new Map([
    ...bothStatesCovered,
    ["Record_Health_Check__mdt.Category__c", new Set(["COMPLETENESS"])]
  ]);
  assert.deepEqual(coverageGaps(declared, used), []);
});

test("reads a namespace's merge-token properties out of its resolver method", () => {
  const resolver = `public with sharing class R {
  private static Object checkValue(String property, Object context) {
    if (property == 'masterLabel') return c.MasterLabel;
    if (property == 'category') return c.Category__c;
    return null;
  }

  private static Object setValue(String property, Object context) {
    if (property == 'setLabel') return s.MasterLabel;
    return null;
  }
}`;
  assert.deepEqual(tokenProperties(resolver, "checkValue"), [
    "masterLabel",
    "category"
  ]);
  assert.deepEqual(tokenProperties(resolver, "setValue"), ["setLabel"]);
  assert.deepEqual(tokenProperties(resolver, "missingValue"), []);
});

test("reads the inline format modifier values out of their constants", () => {
  const source = `public class F {
  public static final String FORMAT_AUTO = 'AUTO';
  public static final String FORMAT_RATIO_PERCENT = 'RATIO_PERCENT';
  private static final String DEFAULT_LOCALE = 'en_US';
}`;
  assert.deepEqual(displayFormats(source), ["AUTO", "RATIO_PERCENT"]);
});

test("reports the surface items no fixture renders", () => {
  const required = new Map([
    ["Merge token rhcCheck", ["masterLabel", "category"]],
    ['Inline format="…" modifier', ["AUTO"]]
  ]);
  const seen = new Map([
    ["Merge token rhcCheck", new Set(["masterLabel"])],
    ['Inline format="…" modifier', new Set(["AUTO"])]
  ]);
  assert.deepEqual(surfaceGaps(required, seen), [
    "Merge token rhcCheck has no integration-test fixture for: category"
  ]);
  assert.deepEqual(surfaceGaps(required, new Map()), [
    'Inline format="…" modifier has no integration-test fixture for: AUTO',
    "Merge token rhcCheck has no integration-test fixture for: masterLabel, category"
  ]);
});

test("reads the character limit a text field declares, and none for a picklist", () => {
  assert.equal(
    fieldLength(
      "<CustomField><type>Text</type><length>255</length></CustomField>"
    ),
    255
  );
  assert.equal(
    fieldLength("<CustomField><type>Picklist</type></CustomField>"),
    null
  );
});

// Salesforce refuses the whole deployment when a fixture is one character over,
// and every gate here reads source only, so nothing else can catch it first.
test("reports a fixture value longer than the field stores", () => {
  const limits = new Map([
    ["Record_Health_Check_Set__mdt.CardSubtitle__c", 255]
  ]);
  const records = [
    {
      file: "Record_Health_Check_Set.Account_Advanced_Checks",
      label: "Coverage: Advanced Account Patterns",
      values: [
        ["Record_Health_Check_Set__mdt.CardSubtitle__c", "x".repeat(256)]
      ]
    }
  ];
  assert.deepEqual(lengthGaps(limits, records), [
    "Record_Health_Check_Set.Account_Advanced_Checks CardSubtitle__c is 256 characters; the field stores 255"
  ]);
  records[0].values[0][1] = "x".repeat(255);
  assert.deepEqual(lengthGaps(limits, records), []);
});

test("reports a record label past the platform's own cap", () => {
  const over = "x".repeat(MAX_MASTER_LABEL + 1);
  const findings = lengthGaps(new Map(), [
    {
      file: "Record_Health_Check_Set.RHC_Persona_Access",
      label: over,
      values: []
    }
  ]);
  assert.equal(findings.length, 1);
  assert.match(findings[0], /caps a Custom Metadata label at 40/);
});
