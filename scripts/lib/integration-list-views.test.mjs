import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const integrationRoots = [
  "packages/record-health-check/integration-tests/main/default",
  "packages/record-health-check/integration-tests/foreign-apex-namespace/main/default",
  "packages/record-health-check/integration-tests/foreign-namespace/main/default"
];
const expectedColumns = [
  "MasterLabel",
  "CheckTitle__c",
  "EvaluationType__c",
  "EvaluationOrder__c",
  "IsActive__c"
];
const normalizedXml = (file) =>
  fs.readFileSync(file, "utf8").replace(/\s+/g, " ");

function fieldValue(xml, fieldName) {
  return [...xml.matchAll(/<values\s*>(.*?)<\/values>/g)]
    .map(([, block]) => block)
    .find((block) => block.includes(`<field>${fieldName}</field>`))
    ?.match(/<value(?:\s[^>]*)?>([^<]+)<\/value>/)?.[1];
}

function verifyIntegrationRoot(integrationRoot) {
  const customMetadataDirectory = path.join(integrationRoot, "customMetadata");
  const listViewDirectory = path.join(
    integrationRoot,
    "objects/Record_Health_Check__mdt/listViews"
  );
  const sets = fs
    .readdirSync(customMetadataDirectory)
    .filter((name) => name.startsWith("Record_Health_Check_Set."))
    .map((fileName) => {
      const developerName = fileName
        .replace("Record_Health_Check_Set.", "")
        .replace(".md-meta.xml", "");
      const xml = normalizedXml(path.join(customMetadataDirectory, fileName));
      return {
        developerName,
        label: xml.match(/<label\s*>([^<]+)<\/label>/)[1]
      };
    });
  const checksBySet = new Map(
    sets.map(({ developerName }) => [developerName, 0])
  );
  for (const fileName of fs
    .readdirSync(customMetadataDirectory)
    .filter((name) => name.startsWith("Record_Health_Check."))) {
    const setName = fieldValue(
      normalizedXml(path.join(customMetadataDirectory, fileName)),
      "Record_Health_Check_Set__c"
    );
    assert.ok(checksBySet.has(setName), `${fileName} references ${setName}`);
    checksBySet.set(setName, checksBySet.get(setName) + 1);
  }

  const listViewFiles = fs
    .readdirSync(listViewDirectory)
    .filter((name) => name.endsWith(".listView-meta.xml"))
    .sort();
  assert.deepEqual(
    listViewFiles,
    sets.map(({ developerName }) => `${developerName}.listView-meta.xml`).sort()
  );

  for (const { developerName, label } of sets) {
    assert.ok(label.length <= 40, `${developerName} label fits Salesforce`);
    const xml = normalizedXml(
      path.join(listViewDirectory, `${developerName}.listView-meta.xml`)
    );
    assert.equal(
      xml.match(/<fullName\s*>([^<]+)<\/fullName>/)[1],
      developerName
    );
    assert.equal(xml.match(/<label\s*>([^<]+)<\/label>/)[1], label);
    assert.equal(
      xml.match(/<filterScope\s*>([^<]+)<\/filterScope>/)[1],
      "Everything"
    );
    assert.deepEqual(
      [...xml.matchAll(/<columns\s*>([^<]+)<\/columns>/g)].map(
        ([, column]) => column
      ),
      expectedColumns
    );
    assert.match(
      xml,
      new RegExp(
        `<filters> <field>Record_Health_Check_Set__c</field> <operation>equals</operation> <value>${developerName}</value> </filters>`
      )
    );
  }
  return sets.length;
}

test("every integration Check Set has an administrator list view for its Checks", () => {
  assert.equal(
    integrationRoots.reduce(
      (total, integrationRoot) =>
        total + verifyIntegrationRoot(integrationRoot),
      0
    ),
    82
  );
});
