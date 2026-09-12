import assert from "node:assert/strict";
import test from "node:test";

import {
  assertUrlStoryEvidence,
  formatUrlStorySummary
} from "../scripts/lib/url-story-verifier.mjs";

const matrix = {
  checkSet: "RHC_Link_Conditions",
  checks: [
    "RHC_Link_Metadata",
    "RHC_Link_Apex_Legacy",
    "RHC_Link_Apex_Structured"
  ],
  records: [
    {
      name: "RHC Link Healthy",
      status: "PASS",
      reasons: {
        RHC_Link_Metadata: null,
        RHC_Link_Apex_Legacy: "APPROVALS_ACTIVE",
        RHC_Link_Apex_Structured: "APPROVALS_ACTIVE"
      },
      summary: { pass: 3, fail: 0, skip: 0, unable: 0, systemError: 0 }
    }
  ],
  transition: {
    record: "RHC Link Healthy",
    statuses: ["PASS", "FAIL", "PASS"]
  },
  displayCases: [
    {
      record: "RHC Link Healthy",
      check: "RHC_Link_Apex_Structured",
      groupedLinks: true
    },
    {
      record: "RHC Link Healthy",
      check: "RHC_Link_Apex_Legacy",
      structured: false,
      foundText: "Step 1\nStep 2"
    }
  ]
};

const structuredDisplay = {
  evaluation: {
    recordName: "RHC Link Healthy",
    checkDeveloperName: "RHC_Link_Apex_Structured"
  },
  display: {
    foundDisplayValue:
      "Step 1: User One\nStep 2: User One, User One\nStep 3: User One, User One, User One",
    displayContent: {
      found: [
        { kind: "link", text: "Step 1", href: "/lightning/r/Account/001/view" },
        { kind: "text", text: ": ", href: null },
        { kind: "link", text: "User One", href: "/lightning/r/User/005/view" },
        { kind: "break", text: null, href: null },
        { kind: "link", text: "Step 2", href: "/lightning/r/Account/001/view" },
        { kind: "text", text: ": ", href: null },
        { kind: "link", text: "User One", href: "/lightning/r/User/005/view" },
        { kind: "text", text: ", ", href: null },
        { kind: "link", text: "User One", href: "/lightning/r/User/005/view" },
        { kind: "break", text: null, href: null },
        { kind: "link", text: "Step 3", href: "/lightning/r/Account/001/view" },
        { kind: "text", text: ": ", href: null },
        { kind: "link", text: "User One", href: "/lightning/r/User/005/view" },
        { kind: "text", text: ", ", href: null },
        { kind: "link", text: "User One", href: "/lightning/r/User/005/view" },
        { kind: "text", text: ", ", href: null },
        { kind: "link", text: "User One", href: "/lightning/r/User/005/view" }
      ]
    }
  }
};

const evidence = {
  checkSetDeveloperName: "RHC_Link_Conditions",
  baseline: [
    {
      recordName: "RHC Link Healthy",
      checkDeveloperName: "RHC_Link_Metadata",
      status: "PASS",
      reasonCode: null
    },
    {
      recordName: "RHC Link Healthy",
      checkDeveloperName: "RHC_Link_Apex_Legacy",
      status: "PASS",
      reasonCode: "APPROVALS_ACTIVE"
    },
    {
      recordName: "RHC Link Healthy",
      checkDeveloperName: "RHC_Link_Apex_Structured",
      status: "PASS",
      reasonCode: "APPROVALS_ACTIVE"
    }
  ],
  displays: [
    structuredDisplay,
    {
      evaluation: {
        recordName: "RHC Link Healthy",
        checkDeveloperName: "RHC_Link_Apex_Legacy"
      },
      display: {
        foundDisplayValue: "Step 1\nStep 2",
        displayContent: {
          found: [
            { kind: "text", text: "Step 1", href: null },
            { kind: "break", text: null, href: null },
            { kind: "text", text: "Step 2", href: null }
          ]
        }
      }
    }
  ],
  transition: [
    { phase: "before", statuses: ["PASS", "PASS", "PASS"] },
    { phase: "changed", statuses: ["FAIL", "FAIL", "FAIL"] },
    { phase: "restored", statuses: ["PASS", "PASS", "PASS"] }
  ]
};

test("accepts the exact matrix, structured lines, and PASS-FAIL-PASS transition", () => {
  assert.doesNotThrow(() => assertUrlStoryEvidence(matrix, evidence));
});

test("rejects a missing or extra baseline result", () => {
  assert.throws(
    () =>
      assertUrlStoryEvidence(matrix, {
        ...evidence,
        baseline: evidence.baseline.slice(1)
      }),
    /baseline result count/
  );
});

test("rejects flattened structured groups", () => {
  const flattened = structuredClone(evidence);
  flattened.displays[0].display.displayContent.found = [
    { kind: "text", text: "Step 1: User One, Step 2: User One", href: null }
  ];
  assert.throws(() => assertUrlStoryEvidence(matrix, flattened), /nine links/);
});

test("rejects an incomplete transition", () => {
  const incomplete = structuredClone(evidence);
  incomplete.transition.pop();
  assert.throws(
    () => assertUrlStoryEvidence(matrix, incomplete),
    /transition phases/
  );
});

test("accepts a coalesced plain-text guide fallback while other links survive", () => {
  const fallbackMatrix = structuredClone(matrix);
  fallbackMatrix.displayCases.push({
    record: "RHC Link Healthy",
    check: "RHC_Link_Metadata",
    guideKind: "text"
  });
  const fallbackEvidence = structuredClone(evidence);
  fallbackEvidence.displays.push({
    evaluation: {
      recordName: "RHC Link Healthy",
      checkDeveloperName: "RHC_Link_Metadata"
    },
    display: {
      displayContent: {
        found: [
          { kind: "link", text: "Step 1", href: "/001" },
          { kind: "text", text: ", Approval guide", href: null }
        ]
      }
    }
  });
  assert.doesNotThrow(() =>
    assertUrlStoryEvidence(fallbackMatrix, fallbackEvidence)
  );
});

test("verification summary reflects the executed matrix", () => {
  assert.equal(
    formatUrlStorySummary(matrix),
    "URL story verified: 1 record, 3 Checks, PASS→FAIL→PASS."
  );
  assert.equal(
    formatUrlStorySummary({
      ...matrix,
      records: Array(9).fill({}),
      checks: ["one", "two"],
      transition: { statuses: ["FAIL", "PASS", "FAIL"] }
    }),
    "URL story verified: 9 records, 2 Checks, FAIL→PASS→FAIL."
  );
});
