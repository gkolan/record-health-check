import assert from "node:assert/strict";
import test from "node:test";
import { formatScratchCapacity } from "./salesforce-limits.mjs";

test("scratch capacity states usage and availability without reversing them", () => {
  assert.equal(
    formatScratchCapacity(
      "devhub",
      { remaining: 22, max: 40 },
      { remaining: 3, max: 5 }
    ),
    "Scratch-org capacity on devhub: 18 of 40 active orgs are in use; 22 active slots are available. Today, 2 of 5 creations have been used; 3 creations are available."
  );
});
