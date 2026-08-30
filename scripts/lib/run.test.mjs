import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";

const moduleUrl = new URL("./run.mjs", import.meta.url).href;

function invoke(source) {
  return spawnSync(
    process.execPath,
    ["--input-type=module", "--eval", source],
    { encoding: "utf8" }
  );
}

test("tryRun reports a missing executable instead of returning a negative answer", () => {
  const result = invoke(
    `import { tryRun } from ${JSON.stringify(moduleUrl)}; tryRun("rhc-command-that-does-not-exist");`
  );

  assert.equal(result.status, 1);
  assert.match(result.stderr, /command was not found/i);
  assert.match(result.stderr, /rhc-command-that-does-not-exist/);
});

test("runCapture reports when the child is killed by a signal", () => {
  const childSource = "process.kill(process.pid, 'SIGKILL')";
  const result = invoke(
    `import { runCapture } from ${JSON.stringify(moduleUrl)}; runCapture(process.execPath, ["--eval", ${JSON.stringify(childSource)}]);`
  );

  assert.equal(result.status, 1);
  assert.match(result.stderr, /terminated by signal SIGKILL/);
});
