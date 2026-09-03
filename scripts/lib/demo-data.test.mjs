import assert from "node:assert/strict";
import test from "node:test";
import path from "node:path";
import { seedDemoData } from "./demo-data.mjs";

function runner(failStep, calls) {
  return (_command, args) => {
    const step = path.basename(args[args.indexOf("--file") + 1]);
    calls.push(step);
    return {
      status: step === failStep ? 1 : 0,
      stdout: JSON.stringify(
        step === failStep
          ? { status: 1, message: "Seed failed" }
          : { status: 0, result: { success: true, logs: "" } }
      ),
      stderr: ""
    };
  };
}

test("demo owner is deactivated even when business-data seeding fails", () => {
  const calls = [];
  assert.throws(
    () => seedDemoData("test-org", runner("setupDemoData.apex", calls)),
    /Seed failed/
  );
  assert.deepEqual(calls, [
    "setupDemoUser.apex",
    "setupDemoData.apex",
    "deactivateDemoUser.apex"
  ]);
});

test("all data is seeded between user setup and deactivation", () => {
  const calls = [];
  seedDemoData("test-org", runner(null, calls));
  assert.deepEqual(calls, [
    "setupDemoUser.apex",
    "setupDemoData.apex",
    "setupReadinessData.apex",
    "deactivateDemoUser.apex"
  ]);
});

test("demo owner deactivation failure is reported", () => {
  assert.throws(
    () => seedDemoData("test-org", runner("deactivateDemoUser.apex", [])),
    /deactivateDemoUser.apex: Seed failed/
  );
});
