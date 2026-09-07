import { strict as assert } from "node:assert";
import { test } from "node:test";

import {
  gateEnvironment,
  gatesFor,
  releaseGates,
  selectGates,
  sourceGates
} from "./release-gates.mjs";

test("every environment runs the source gates behind its toolchain gate", () => {
  assert.equal(gatesFor("ci")[0], "check:toolchain-policy");
  assert.equal(gatesFor("local")[0], "check:toolchain-latest");
  assert.deepEqual(gatesFor("ci").slice(1), sourceGates);
  assert.deepEqual(gatesFor("local").slice(1), [
    ...sourceGates,
    ...releaseGates
  ]);
});

test("release gates run for a release and not on a pull request", () => {
  // A release gate spends something - a model call, an org, quota - that a
  // contributor's pull request must not spend, so hosted CI must not pick it
  // up by running the same list.
  assert.ok(releaseGates.length > 0);
  for (const gate of releaseGates) {
    assert.ok(
      !sourceGates.includes(gate),
      `${gate} is declared as both a source gate and a release gate`
    );
    assert.ok(gatesFor("local").includes(gate), `${gate} never runs`);
    assert.ok(!gatesFor("ci").includes(gate), `${gate} runs on every PR`);
  }
});

test("selection keeps declared order, not the order requested", () => {
  const gates = ["a", "b", "c"];
  assert.deepEqual(selectGates(gates, ["c", "a"]), ["a", "c"]);
});

test("selection trims surrounding whitespace", () => {
  assert.deepEqual(selectGates(["a", "b"], [" a ", "b"]), ["a", "b"]);
});

test("a name that is only a prefix of real gates is rejected", () => {
  // Three declared gates start with "check:code-analyzer". Substring matching
  // would silently run all three; exact matching must refuse the name.
  const prefixed = sourceGates.filter((gate) =>
    gate.startsWith("check:code-analyzer")
  );
  assert.ok(prefixed.length > 1, "expected several code-analyzer gates");
  assert.throws(
    () => selectGates(gatesFor("ci"), ["check:code-analyzer"]),
    /Unknown gate name/
  );
});

test("an unknown gate names itself and points at --list", () => {
  assert.throws(
    () => selectGates(["a"], ["nope"]),
    /Unknown gate name\(s\): nope/
  );
  assert.throws(() => selectGates(["a"], ["nope"]), /--list/);
});

test("an empty selection is an error rather than a silent no-op", () => {
  assert.throws(() => selectGates(["a"], []), /at least one gate/);
  assert.throws(() => selectGates(["a"], ["", "  "]), /at least one gate/);
});

test("CI gate mode is propagated to child commands", () => {
  assert.deepEqual(gateEnvironment("ci", { PATH: "/tools" }), {
    PATH: "/tools",
    CI: "true"
  });
  assert.deepEqual(gateEnvironment("local", { PATH: "/tools" }), {
    PATH: "/tools"
  });
});
