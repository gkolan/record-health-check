import assert from "node:assert/strict";
import test from "node:test";
import {
  assertHostedEvidence,
  hostedEvidenceContract
} from "./hosted-evidence.mjs";

test("green workflow alone is insufficient without every job and artifact", () => {
  const run = { head_sha: "abc", run_started_at: "2026-01-01T00:00:00Z" };
  const jobs = [
    { name: "required", status: "completed", conclusion: "success" }
  ];
  const artifacts = [
    {
      name: "proof",
      size_in_bytes: 100,
      expired: false,
      created_at: "2026-01-01T00:01:00Z",
      expires_at: "2099-01-01T00:00:00Z",
      workflow_run: { head_sha: "abc" }
    }
  ];
  const contract = { jobs: ["required"], artifacts: ["proof"] };
  assert.doesNotThrow(() =>
    assertHostedEvidence(run, jobs, artifacts, contract)
  );
  for (const conclusion of ["skipped", "cancelled", "failure", null]) {
    assert.throws(() =>
      assertHostedEvidence(
        run,
        [{ ...jobs[0], conclusion }],
        artifacts,
        contract
      )
    );
  }
  assert.throws(() => assertHostedEvidence(run, [], artifacts, contract));
  assert.throws(() => assertHostedEvidence(run, jobs, [], contract));
  for (const change of [
    { expired: true },
    { size_in_bytes: 0 },
    { created_at: "2025-01-01T00:00:00Z" },
    { expires_at: "2025-01-01T00:00:00Z" },
    { workflow_run: { head_sha: "other" } }
  ]) {
    assert.throws(() =>
      assertHostedEvidence(
        run,
        jobs,
        [{ ...artifacts[0], ...change }],
        contract
      )
    );
  }
});

test("source and each subscriber stage require their own evidence", () => {
  assert.equal(hostedEvidenceContract().jobs.length, 5);
  assert.equal(hostedEvidenceContract("04t", "clean-install").jobs.length, 3);
  assert.equal(
    hostedEvidenceContract("04t", "upgrade-2.0.4.2").artifacts.length,
    6
  );
  assert.notDeepEqual(
    hostedEvidenceContract("04t", "upgrade-2.0.4.2").artifacts,
    hostedEvidenceContract("04t", "upgrade-2.0.6.2").artifacts
  );
  assert.throws(() => hostedEvidenceContract("04t"));
});
