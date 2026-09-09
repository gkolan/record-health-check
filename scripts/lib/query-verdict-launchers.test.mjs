import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = process.cwd();
const metadataDirectory = path.join(
  root,
  "packages/record-health-check/integration-tests/main/default/customMetadata"
);
const launcherDirectory = path.join(
  root,
  "packages/record-health-check/integration-tests/scripts"
);

test("exhaustive smoke launchers cover every integration Check", () => {
  const checkCount = fs
    .readdirSync(metadataDirectory)
    .filter((name) =>
      /^Record_Health_Check\.[^.]+\.md-meta\.xml$/.test(name)
    ).length;
  const expectedOffsets = Array.from(
    { length: Math.ceil(checkCount / 50) },
    (_, index) => index * 50
  );
  const actualOffsets = fs
    .readdirSync(launcherDirectory)
    .map((name) => name.match(/^exhaustive_smoke_checks_(\d+)\.apex$/)?.[1])
    .filter(Boolean)
    .map(Number)
    .sort((left, right) => left - right);

  assert.deepEqual(
    actualOffsets,
    expectedOffsets,
    `${checkCount} integration Checks require one launcher for every 50-record slice`
  );
});
