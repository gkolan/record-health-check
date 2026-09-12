import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();
const contract = JSON.parse(
  fs.readFileSync("tests/fixtures/card-heading/contract.json", "utf8")
);
const metadata =
  "packages/record-health-check/integration-tests/main/default/customMetadata";
const read = (name) =>
  fs.readFileSync(path.join(root, metadata, name + ".md-meta.xml"), "utf8");
const values = (xml) =>
  Object.fromEntries(
    [...xml.matchAll(/<values>([\s\S]*?)<\/values>/g)].map((match) => [
      match[1].match(/<field>([^<]+)<\/field>/)[1],
      match[1].match(/<value[^>]*>([\s\S]*?)<\/value>/)?.[1].trim() ?? null
    ])
  );

test("heading fixtures cover every valid heading/button/run combination", () => {
  for (const heading of ["TITLE_AND_SUBTITLE", "TITLE_ONLY", "HIDE"]) {
    for (const button of [
      "LABEL_AND_ICON",
      "LABEL_ONLY",
      "ICON_ONLY",
      "HIDE"
    ]) {
      for (const run of ["RUN_ON_LOAD", "RUN_ON_REQUEST"]) {
        if (button === "HIDE" && run === "RUN_ON_REQUEST") continue;
        assert.ok(
          contract.sets.some(
            (row) =>
              row.heading === heading &&
              row.button === button &&
              row.run === run
          )
        );
      }
    }
  }
});

test("heading field preserves exact labels, default and package membership", () => {
  const xml = fs.readFileSync(
    "packages/record-health-check/force-app/main/default/objects/Record_Health_Check_Set__mdt/fields/CardHeadingDisplay__c.field-meta.xml",
    "utf8"
  );
  const entries = [...xml.matchAll(/<value>([\s\S]*?)<\/value>/g)].map((m) => [
    m[1].match(/<fullName>([^<]+)<\/fullName>/)[1],
    m[1].match(/<label\s*>([^<]+)<\/label>/)[1],
    m[1].match(/<default>([^<]+)<\/default>/)[1]
  ]);
  assert.deepEqual(entries, [
    ["TITLE_AND_SUBTITLE", "Show title and subtitle", "true"],
    ["TITLE_ONLY", "Show title only", "false"],
    ["HIDE", "Hide", "false"]
  ]);
  assert.match(xml, /<restricted>true<\/restricted>/);
  assert.match(
    fs.readFileSync(
      "packages/record-health-check/manifest/package.xml",
      "utf8"
    ),
    /Record_Health_Check_Set__mdt.CardHeadingDisplay__c/
  );
});

test("every heading Set has its paired record-dependent Check and exact configuration", () => {
  for (const row of contract.sets) {
    const set = values(read("Record_Health_Check_Set." + row.name));
    assert.equal(set.CardHeadingDisplay__c ?? null, row.heading);
    assert.equal(set.RunButtonDisplay__c, row.button);
    assert.equal(set.CardRunMode__c, row.run);
    assert.equal(set.CardRevealMode__c, row.reveal);
    assert.equal(set.SummaryDisplay__c, row.summary);
    assert.equal(set.PassedChecksDisplay__c, row.passed);
    const check = values(
      read("Record_Health_Check." + row.name + "_Employees")
    );
    assert.equal(check.Record_Health_Check_Set__c, row.name);
    assert.equal(check.IsActive__c, String(row.activeCheck));
    assert.equal(
      check.PassConditionFormula__c,
      "BLANKVALUE(NumberOfEmployees, 0) &gt; 0"
    );
    assert.equal(check.FailureSeverity__c, "WARNING");
    assert.equal(
      check.ApplicabilityMode__c,
      row.skipped ? "WHEN_FORMULA_TRUE" : "ALL_RECORDS"
    );
    if (row.skipped)
      assert.equal(check.ApplicabilityFormula__c, "NumberOfEmployees &gt; 0");
  }
});

test("heading fixture inventory has no orphan metadata and every scenario has a procedure", () => {
  const files = fs
    .readdirSync(metadata)
    .filter((name) => /^Record_Health_Check(?:_Set)?\.RHC_Heading_/.test(name));
  assert.equal(files.length, contract.sets.length * 2);
  const guide = fs.readFileSync(
    "packages/record-health-check/integration-tests/card-heading-display.md",
    "utf8"
  );
  for (const row of contract.sets)
    assert.ok(guide.includes(row.name), row.name);
  for (let n = 1; n <= 21; n++) {
    const id = `S-${String(n).padStart(2, "0")}`;
    assert.ok(contract.scenarios[id]);
    assert.ok(guide.includes(id), id);
  }
});
