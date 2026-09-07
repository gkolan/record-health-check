import assert from "node:assert/strict";
import test from "node:test";
import { freshnessProblems } from "./ai-draft-freshness.mjs";

const model = "claude-haiku-4-5-20251001";
const fingerprints = new Map([["query", "abc"]]);
const present = () => true;
const manifest = (recording) => ({ recordings: { query: recording } });
const fresh = { file: "m-query.md", model, promptSha256: "abc" };

test("a recording of the current prompt is accepted", () => {
  assert.deepEqual(
    freshnessProblems(manifest(fresh), fingerprints, model, present),
    []
  );
});

test("an edited prompt makes its recording stale", () => {
  const problems = freshnessProblems(
    manifest({ ...fresh, promptSha256: "old", recordedAt: "2026-01-01" }),
    fingerprints,
    model,
    present
  );
  assert.equal(problems.length, 1);
  assert.match(problems[0], /prompt changed since m-query\.md was recorded/);
});

test("a missing recording is reported", () => {
  const problems = freshnessProblems(
    { recordings: {} },
    fingerprints,
    model,
    present
  );
  assert.match(problems[0], /No claude-haiku-4-5-20251001 recording/);
});

test("evidence from a more capable model does not count", () => {
  const problems = freshnessProblems(
    manifest({ ...fresh, model: "claude-opus-5" }),
    fingerprints,
    model,
    present
  );
  assert.match(problems[0], /not the lowest-cost model/);
});

test("a recorded file that is gone is reported", () => {
  const problems = freshnessProblems(
    manifest(fresh),
    fingerprints,
    model,
    () => false
  );
  assert.equal(problems.length, 1);
  assert.match(problems[0], /missing from the folder/);
});

test("a recording for a prompt that no longer exists is reported", () => {
  const problems = freshnessProblems(
    { recordings: { query: fresh, legacy: fresh } },
    fingerprints,
    model,
    present
  );
  assert.match(problems[0], /remove the stale recording/);
});
