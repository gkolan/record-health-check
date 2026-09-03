import assert from "node:assert/strict";
import test from "node:test";
import {
  acceptanceScenarios,
  assertReleaseAcceptance
} from "./release-acceptance.mjs";

test("promotion acceptance is exact-candidate, reviewed, and complete", () => {
  const evidence = {
    subscriberPackageVersionId: "04t",
    gitCommit: "sha",
    verifiedBy: "release owner",
    verifiedAt: new Date().toISOString(),
    scenarios: Object.fromEntries(
      acceptanceScenarios.map((s) => [
        s,
        { status: "pass", evidence: "restricted test record" }
      ])
    )
  };
  assert.doesNotThrow(() => assertReleaseAcceptance(evidence, "04t", "sha"));
  assert.throws(() => assertReleaseAcceptance(evidence, "other", "sha"));
  assert.throws(() => assertReleaseAcceptance(evidence, "04t", "other"));
  assert.throws(() =>
    assertReleaseAcceptance({ ...evidence, verifiedBy: "" }, "04t", "sha")
  );
  assert.throws(() =>
    assertReleaseAcceptance(
      { ...evidence, verifiedAt: "2000-01-01" },
      "04t",
      "sha"
    )
  );
  for (const s of acceptanceScenarios) {
    assert.throws(() =>
      assertReleaseAcceptance(
        {
          ...evidence,
          scenarios: {
            ...evidence.scenarios,
            [s]: { status: "pending", evidence: "" }
          }
        },
        "04t",
        "sha"
      )
    );
  }
});
