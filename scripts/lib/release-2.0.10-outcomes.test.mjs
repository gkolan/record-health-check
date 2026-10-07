import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const contractPath = "tests/fixtures/release-2.0.10/outcome-contract.json";
const contract = JSON.parse(fs.readFileSync(contractPath, "utf8"));
const expectedFeatures = [
  "apex-parameters",
  "typed-outcomes",
  "per-record-recovery",
  "evidence",
  "presentation",
  "formula-planning",
  "diagnostics",
  "detached-preview",
  "readiness",
  "check-authoring",
  "card-heading"
];

const cloneContract = () => JSON.parse(JSON.stringify(contract));

const verifyContract = (candidate) => {
  assert.equal(candidate.version, "2.0.10");
  const candidateFeatureIds = candidate.features.map(({ id }) => id);
  assert.equal(
    new Set(candidateFeatureIds).size,
    candidate.features.length,
    "Feature identifiers must be unique."
  );
  assert.deepEqual(candidateFeatureIds, expectedFeatures);

  for (const feature of candidate.features) {
    assert.ok(
      feature.requiredOutcomes.includes("RECOVERY"),
      `${feature.id} must declare recovery behavior.`
    );
    assert.ok(
      feature.requiredOutcomes.length >= 3,
      `${feature.id} must distinguish success from adverse behavior.`
    );
    assert.deepEqual(Object.keys(feature.anchors), [
      "success",
      "adverse",
      "recovery"
    ]);

    const allAnchors = Object.values(feature.anchors).flat();
    assert.ok(
      allAnchors.some(({ file }) => file.includes("/integration-tests/")),
      `${feature.id} must retain integration-test evidence.`
    );
    for (const [phase, anchors] of Object.entries(feature.anchors)) {
      assert.ok(
        anchors.length > 0,
        `${feature.id} is missing ${phase} evidence.`
      );
      for (const anchor of anchors) {
        assert.ok(fs.existsSync(anchor.file), `${anchor.file} does not exist.`);
        const source = fs.readFileSync(anchor.file, "utf8");
        for (const marker of anchor.contains) {
          assert.ok(
            source.includes(marker),
            `${feature.id} ${phase} evidence lost ${marker} in ${anchor.file}.`
          );
        }
      }
    }
  }
};

test("every public 2.0.10 feature retains success, adverse, and recovery evidence", () => {
  verifyContract(contract);
});

test("the 2.0.10 outcome gate rejects a missing feature", () => {
  const candidate = cloneContract();
  candidate.features.pop();
  assert.throws(() => verifyContract(candidate));
});

test("the 2.0.10 outcome gate rejects duplicate feature identifiers", () => {
  const candidate = cloneContract();
  candidate.features[1].id = candidate.features[0].id;
  assert.throws(
    () => verifyContract(candidate),
    /Feature identifiers must be unique/
  );
});

test("the 2.0.10 outcome gate rejects missing integration evidence", () => {
  const candidate = cloneContract();
  for (const anchors of Object.values(candidate.features[0].anchors)) {
    for (const anchor of anchors) {
      anchor.file =
        "packages/record-health-check/force-app/main/default/classes/RHCSubscriberDefinitionSpecTest.cls";
    }
  }
  assert.throws(
    () => verifyContract(candidate),
    /apex-parameters must retain integration-test evidence/
  );
});

test("the 2.0.10 outcome gate rejects a stale regression anchor", () => {
  const candidate = cloneContract();
  candidate.features[0].anchors.success[0].contains = [
    "removedRegressionMethod"
  ];
  assert.throws(
    () => verifyContract(candidate),
    /apex-parameters success evidence lost removedRegressionMethod/
  );
});
