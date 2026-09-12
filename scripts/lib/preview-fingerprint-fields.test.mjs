import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import test from "node:test";

const metadataRoot = "packages/record-health-check/force-app/main/default";

test("Preview fingerprint selector loads every shipped Check Set field", async () => {
  const source = await readFile(
    `${metadataRoot}/classes/RecordHealthCheckPreviewService.cls`,
    "utf8"
  );
  const selector = source.match(
    /private static Record_Health_Check_Set__mdt loadCheckSet\([\s\S]*?SELECT([\s\S]*?)FROM Record_Health_Check_Set__mdt/
  );
  assert.ok(
    selector,
    "The server-owned Check Set fingerprint selector must be inspectable."
  );
  const selected = new Set(selector[1].split(",").map((field) => field.trim()));
  const files = await readdir(
    `${metadataRoot}/objects/Record_Health_Check_Set__mdt/fields`
  );
  const omitted = files
    .filter((file) => file.endsWith(".field-meta.xml"))
    .map((file) => file.replace(/\.field-meta\.xml$/, ""))
    .filter((field) => !selected.has(field));
  assert.deepEqual(
    omitted,
    [],
    "Omitted fields allow stale readiness after Check Set configuration changes."
  );
});
