import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const corpusPath = path.resolve("tests/fixtures/query-shapes/corpus.json");
const classifierPath = path.resolve(
  "scripts/release/inventory_bulk_query_shapes.py"
);

async function expectedCases() {
  return JSON.parse(await readFile(corpusPath, "utf8")).cases;
}

function classifyCorpus() {
  const result = spawnSync(
    "python3",
    [classifierPath, "--classify-corpus", corpusPath],
    { encoding: "utf8" }
  );
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout);
}

test("C01 Repeated token parity", () => {
  const actual = classifyCorpus().find(({ id }) => id === "C01");
  assert.deepEqual(actual, {
    id: "C01",
    classification: "UNCLASSIFIED",
    supported: false,
    reason: "UNSUPPORTED_BULK_QUERY_SHAPE",
    requiredConjunct: null
  });
});

test("C02 Stale generated corpus", () => {
  const result = spawnSync(
    process.execPath,
    [path.resolve("scripts/release/check_query_shape_contract.mjs")],
    { encoding: "utf8" }
  );
  assert.equal(result.status, 0, result.stderr);
});

test("C03 Corpus complete parity", async () => {
  const expected = (await expectedCases()).map(
    ({ id, classification, supported, reason, requiredConjunct }) => ({
      id,
      classification,
      supported,
      reason,
      requiredConjunct
    })
  );
  assert.deepEqual(classifyCorpus(), expected);
});
