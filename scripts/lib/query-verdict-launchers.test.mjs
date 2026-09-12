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
const exhaustiveHarness = fs.readFileSync(
  path.join(
    root,
    "packages/record-health-check/integration-tests/main/default/classes/RecordHealthCheckExhaustiveSmoke.cls"
  ),
  "utf8"
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
  for (const offset of expectedOffsets) {
    const source = fs.readFileSync(
      path.join(launcherDirectory, `exhaustive_smoke_checks_${offset}.apex`),
      "utf8"
    );
    assert.ok(
      source.includes(`startChecks(target.Id, ${offset})`),
      `Check launcher ${offset} must execute its own slice`
    );
  }
  const capture = fs.readFileSync(
    path.join(root, "scripts/release/capture_query_verdicts.py"),
    "utf8"
  );
  const captureOffsets = capture
    .match(/for offset in \(([^)]+)\)/)[1]
    .split(",")
    .map((value) => Number(value.trim()));
  assert.deepEqual(
    captureOffsets,
    expectedOffsets,
    "capture must run every Check launcher"
  );
  assert.match(
    exhaustiveHarness,
    /FROM Record_Health_Check__mdt\s+ORDER BY DeveloperName\s+LIMIT 50\s+OFFSET :batchOffset/,
    "the Check harness must query every unfiltered 50-record metadata slice"
  );
});

test("the exhaustive Check Set launcher covers the complete integration inventory", () => {
  const checkSetCount = fs
    .readdirSync(metadataDirectory)
    .filter((name) =>
      /^Record_Health_Check_Set\.[^.]+\.md-meta\.xml$/.test(name)
    ).length;
  const launcher = fs.readFileSync(
    path.join(launcherDirectory, "exhaustive_smoke.apex"),
    "utf8"
  );

  const expectedOffsets = Array.from(
    { length: Math.ceil(checkSetCount / 50) },
    (_, index) => index * 50
  );
  const actualOffsets = [
    0,
    ...fs
      .readdirSync(launcherDirectory)
      .map((name) => name.match(/^exhaustive_smoke_sets_(\d+)\.apex$/)?.[1])
      .filter(Boolean)
      .map(Number)
  ].sort((a, b) => a - b);
  assert.deepEqual(
    actualOffsets,
    expectedOffsets,
    "all Set slices need separate transaction launchers"
  );
  for (const offset of expectedOffsets.filter((value) => value > 0)) {
    const source = fs.readFileSync(
      path.join(launcherDirectory, `exhaustive_smoke_sets_${offset}.apex`),
      "utf8"
    );
    assert.ok(
      source.includes(`startSets(target.Id, ${offset})`),
      `Set launcher ${offset} must execute its own slice`
    );
  }
  assert.match(
    launcher,
    /RecordHealthCheckExhaustiveSmoke\.startSets\(/,
    "the maintained launcher must enqueue the complete Check Set inventory"
  );
  assert.match(
    exhaustiveHarness,
    /FROM Record_Health_Check_Set__mdt\s+ORDER BY DeveloperName\s+LIMIT 50\s+OFFSET :batchOffset/,
    "the Check Set harness must query the complete unfiltered metadata inventory"
  );
});
